package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

type projectManifest struct {
	Schema           string `json:"schema"`
	ID               string `json:"id"`
	OpenAPIOperation string `json:"openapi_operation"`
	OpenAPIPath      string `json:"openapi_path"`
	OpenAPIMethod    string `json:"openapi_method"`
	ServiceHandler   string `json:"service_handler"`
	Paths            struct {
		OpenAPI       string `json:"openapi"`
		ServiceSource string `json:"service_source"`
	} `json:"paths"`
}

type openAPIOperation struct {
	OperationID string `json:"operationId"`
}

type openAPIDocument struct {
	Paths map[string]map[string]openAPIOperation `json:"paths"`
}

type counts struct {
	OpenAPIOperations   int `json:"openapi_operation_occurrences"`
	HandlerDefinitions  int `json:"handler_definition_occurrences"`
	HandlerSignatures   int `json:"handler_signature_occurrences"`
	HandlerRegistrations int `json:"handler_registration_occurrences"`
}

func digest(data []byte) string {
	return fmt.Sprintf("sha256:%x", sha256.Sum256(data))
}

func selectorIs(expr ast.Expr, aliases map[string]bool, name string) bool {
	selector, ok := expr.(*ast.SelectorExpr)
	if !ok || selector.Sel.Name != name {
		return false
	}
	ident, ok := selector.X.(*ast.Ident)
	return ok && aliases[ident.Name]
}

func handlerSignature(fn *ast.FuncDecl, aliases map[string]bool) bool {
	if fn.Recv != nil || fn.Type.Params == nil || len(fn.Type.Params.List) != 2 {
		return false
	}
	first := fn.Type.Params.List[0]
	second := fn.Type.Params.List[1]
	if len(first.Names) != 1 || len(second.Names) != 1 {
		return false
	}
	if !selectorIs(first.Type, aliases, "ResponseWriter") {
		return false
	}
	pointer, ok := second.Type.(*ast.StarExpr)
	return ok && selectorIs(pointer.X, aliases, "Request")
}

func emit(project projectManifest, state, reason, nextOperation, unknownClass string, sourceDigest, openAPIDigest string, observed counts) error {
	decision := state
	if state == "CLOSED" {
		decision = "CLOSED"
	}
	receipt := map[string]any{
		"schema":   "gooo/infra-evidence/service-symbol-receipt/v1",
		"decision": decision,
		"subject": map[string]any{
			"project_id":         project.ID,
			"source_file":        project.Paths.ServiceSource,
			"source_digest":      sourceDigest,
			"openapi_file":       project.Paths.OpenAPI,
			"openapi_digest":     openAPIDigest,
		},
		"binding": map[string]any{
			"openapi_operation": project.OpenAPIOperation,
			"openapi_path":      project.OpenAPIPath,
			"openapi_method":    strings.ToUpper(project.OpenAPIMethod),
			"service_handler":   project.ServiceHandler,
			"route_pattern":     strings.ToUpper(project.OpenAPIMethod) + " " + project.OpenAPIPath,
		},
		"counts": observed,
		"claim": map[string]any{
			"state":          state,
			"stage":          "SERVICE_SYMBOL",
			"step":           "BIND_OPENAPI_OPERATION_TO_GO_HANDLER",
			"reason":         reason,
			"next_operation": nextOperation,
			"unknown_class":  unknownClass,
		},
		"authority": map[string]any{
			"go_syntax":       "go/parser",
			"network":         "NOT_USED",
			"source_mutation": "NONE",
		},
	}
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	return encoder.Encode(receipt)
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: observe-service-symbol PROJECT_MANIFEST")
		os.Exit(64)
	}

	projectBytes, err := os.ReadFile(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(66)
	}
	var project projectManifest
	if err := json.Unmarshal(projectBytes, &project); err != nil || project.Schema != "gooo/infra-evidence/project/v2" {
		fmt.Fprintln(os.Stderr, "invalid project manifest")
		os.Exit(65)
	}

	root := filepath.Dir(os.Args[1])
	sourceBytes, sourceErr := os.ReadFile(filepath.Join(root, project.Paths.ServiceSource))
	openAPIBytes, openAPIErr := os.ReadFile(filepath.Join(root, project.Paths.OpenAPI))
	if sourceErr != nil || openAPIErr != nil {
		reason := "SERVICE_SOURCE_UNAVAILABLE"
		next := "PROVIDE_GO_SERVICE_SOURCE"
		if openAPIErr != nil {
			reason = "OPENAPI_CONTRACT_UNAVAILABLE"
			next = "PROVIDE_OPENAPI_CONTRACT"
		}
		if err := emit(project, "UNKNOWN", reason, next, "DIRECT_MISSING", "", "", counts{}); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(74)
		}
		return
	}

	var document openAPIDocument
	if err := json.Unmarshal(openAPIBytes, &document); err != nil {
		_ = emit(project, "REFUTED", "OPENAPI_DOCUMENT_INVALID", "RESTORE_OPENAPI_DOCUMENT", "", digest(sourceBytes), digest(openAPIBytes), counts{})
		return
	}

	observed := counts{}
	for _, methods := range document.Paths {
		for _, operation := range methods {
			if operation.OperationID == project.OpenAPIOperation {
				observed.OpenAPIOperations++
			}
		}
	}
	method := strings.ToLower(project.OpenAPIMethod)
	configuredOperation, configured := document.Paths[project.OpenAPIPath][method]
	if !configured || configuredOperation.OperationID != project.OpenAPIOperation || observed.OpenAPIOperations != 1 {
		_ = emit(project, "REFUTED", "OPENAPI_OPERATION_CARDINALITY_MISMATCH", "RESTORE_UNIQUE_OPENAPI_OPERATION", "", digest(sourceBytes), digest(openAPIBytes), observed)
		return
	}

	fileset := token.NewFileSet()
	file, err := parser.ParseFile(fileset, project.Paths.ServiceSource, sourceBytes, parser.AllErrors)
	if err != nil {
		_ = emit(project, "REFUTED", "GO_SERVICE_SOURCE_INVALID", "RESTORE_PARSEABLE_GO_SERVICE_SOURCE", "", digest(sourceBytes), digest(openAPIBytes), observed)
		return
	}

	httpAliases := map[string]bool{}
	for _, imported := range file.Imports {
		path, err := strconv.Unquote(imported.Path.Value)
		if err != nil || path != "net/http" {
			continue
		}
		alias := "http"
		if imported.Name != nil {
			alias = imported.Name.Name
		}
		if alias != "." && alias != "_" {
			httpAliases[alias] = true
		}
	}

	for _, declaration := range file.Decls {
		function, ok := declaration.(*ast.FuncDecl)
		if !ok || function.Name.Name != project.ServiceHandler {
			continue
		}
		observed.HandlerDefinitions++
		if handlerSignature(function, httpAliases) {
			observed.HandlerSignatures++
		}
	}

	expectedPattern := strings.ToUpper(project.OpenAPIMethod) + " " + project.OpenAPIPath
	ast.Inspect(file, func(node ast.Node) bool {
		call, ok := node.(*ast.CallExpr)
		if !ok || len(call.Args) != 2 {
			return true
		}
		selector, ok := call.Fun.(*ast.SelectorExpr)
		if !ok || selector.Sel.Name != "HandleFunc" {
			return true
		}
		qualifier, ok := selector.X.(*ast.Ident)
		if !ok || !httpAliases[qualifier.Name] {
			return true
		}
		pattern, ok := call.Args[0].(*ast.BasicLit)
		if !ok || pattern.Kind != token.STRING {
			return true
		}
		value, err := strconv.Unquote(pattern.Value)
		if err != nil || value != expectedPattern {
			return true
		}
		handler, ok := call.Args[1].(*ast.Ident)
		if ok && handler.Name == project.ServiceHandler {
			observed.HandlerRegistrations++
		}
		return true
	})

	state := "CLOSED"
	reason := "OPENAPI_OPERATION_BOUND_TO_GO_HANDLER"
	next := "NONE"
	if observed.HandlerDefinitions != 1 {
		state = "REFUTED"
		reason = "GO_HANDLER_DEFINITION_CARDINALITY_MISMATCH"
		next = "RESTORE_UNIQUE_GO_HANDLER_DEFINITION"
	} else if observed.HandlerSignatures != 1 {
		state = "REFUTED"
		reason = "GO_HANDLER_SIGNATURE_MISMATCH"
		next = "RESTORE_HTTP_HANDLER_SIGNATURE"
	} else if observed.HandlerRegistrations != 1 {
		state = "REFUTED"
		reason = "GO_HANDLER_REGISTRATION_CARDINALITY_MISMATCH"
		next = "RESTORE_UNIQUE_METHOD_PATH_REGISTRATION"
	}
	if err := emit(project, state, reason, next, "", digest(sourceBytes), digest(openAPIBytes), observed); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(74)
	}
}
