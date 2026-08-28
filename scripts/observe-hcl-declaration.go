package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/hashicorp/hcl/v2"
	"github.com/hashicorp/hcl/v2/hclsyntax"
)

const (
	parserModule  = "github.com/hashicorp/hcl/v2"
	parserVersion = "v2.24.0"
	parserSum     = "h1:2QJdZ454DSsYGoaE6QheQZjtKZSUs9Nh2izTWiwQxvE="
)

type projectManifest struct {
	Schema           string `json:"schema"`
	ID               string `json:"id"`
	ResourceAddress  string `json:"resource_address"`
	ArtifactDigest   string `json:"artifact_digest"`
	DeploymentTarget string `json:"deployment_target"`
	Paths            struct {
		TerraformDeclaration string `json:"terraform_declaration"`
	} `json:"paths"`
}

type binding struct {
	ResourceAddress string `json:"resource_address"`
	ResourceType    string `json:"resource_type"`
	ResourceName    string `json:"resource_name"`
	Target          string `json:"target"`
	ImageDigest     string `json:"image_digest"`
}

type observedCounts struct {
	ResourceBlocks        int `json:"resource_block_occurrences"`
	TargetAttributes      int `json:"target_attribute_occurrences"`
	ImageDigestAttributes int `json:"image_digest_attribute_occurrences"`
	ParserDiagnostics     int `json:"parser_diagnostics"`
}

type sourceRange struct {
	StartLine   int `json:"start_line"`
	StartColumn int `json:"start_column"`
	EndLine     int `json:"end_line"`
	EndColumn   int `json:"end_column"`
}

func digest(data []byte) string {
	return fmt.Sprintf("sha256:%x", sha256.Sum256(data))
}

func rangeOf(observed hcl.Range) sourceRange {
	return sourceRange{
		StartLine:   observed.Start.Line,
		StartColumn: observed.Start.Column,
		EndLine:     observed.End.Line,
		EndColumn:   observed.End.Column,
	}
}

func emit(project projectManifest, state, reason, nextOperation, unknownClass, sourceDigest string, values binding, counts observedCounts, observedRange sourceRange) error {
	receipt := map[string]any{
		"schema":   "gooo/infra-evidence/hcl-declaration-receipt/v1",
		"decision": state,
		"subject": map[string]any{
			"project_id":    project.ID,
			"source_file":   project.Paths.TerraformDeclaration,
			"source_digest": sourceDigest,
		},
		"binding":      values,
		"counts":       counts,
		"source_range": observedRange,
		"claim": map[string]any{
			"state":          state,
			"stage":          "INFRA_DECLARATION",
			"step":           "PARSE_HCL_TERRAFORM_DECLARATION",
			"reason":         reason,
			"next_operation": nextOperation,
			"unknown_class":  unknownClass,
		},
		"authority": map[string]any{
			"parser_module":       parserModule,
			"parser_version":      parserVersion,
			"parser_sum":          parserSum,
			"parser_package":      "github.com/hashicorp/hcl/v2/hclsyntax",
			"parser_api":          "hclsyntax.ParseConfig",
			"go_toolchain":        runtime.Version(),
			"terraform_execution": "NOT_USED",
			"source_mutation":     "NONE",
		},
	}
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	return encoder.Encode(receipt)
}

func stringAttribute(attribute *hclsyntax.Attribute) (string, bool, bool) {
	if attribute == nil {
		return "", false, false
	}
	value, diagnostics := attribute.Expr.Value(nil)
	if diagnostics.HasErrors() || !value.IsKnown() || value.IsNull() || value.Type().FriendlyName() != "string" {
		return "", true, false
	}
	return value.AsString(), true, true
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: observe-hcl-declaration PROJECT_MANIFEST")
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

	address := strings.Split(project.ResourceAddress, ".")
	values := binding{ResourceAddress: project.ResourceAddress}
	if len(address) != 2 || address[0] == "" || address[1] == "" {
		_ = emit(project, "REFUTED", "TERRAFORM_RESOURCE_ADDRESS_INVALID", "RESTORE_TERRAFORM_RESOURCE_ADDRESS", "", "", values, observedCounts{}, sourceRange{})
		return
	}
	values.ResourceType = address[0]
	values.ResourceName = address[1]

	root := filepath.Dir(os.Args[1])
	sourcePath := filepath.Join(root, project.Paths.TerraformDeclaration)
	sourceBytes, err := os.ReadFile(sourcePath)
	if err != nil {
		_ = emit(project, "UNKNOWN", "HCL_TERRAFORM_DECLARATION_UNAVAILABLE", "PROVIDE_HCL_TERRAFORM_DECLARATION", "DIRECT_MISSING", "", values, observedCounts{}, sourceRange{})
		return
	}

	file, diagnostics := hclsyntax.ParseConfig(sourceBytes, project.Paths.TerraformDeclaration, hcl.Pos{Line: 1, Column: 1})
	counts := observedCounts{ParserDiagnostics: len(diagnostics)}
	if diagnostics.HasErrors() || file == nil {
		_ = emit(project, "REFUTED", "HCL_TERRAFORM_DECLARATION_INVALID", "RESTORE_PARSEABLE_HCL_TERRAFORM_DECLARATION", "", digest(sourceBytes), values, counts, sourceRange{})
		return
	}
	body, ok := file.Body.(*hclsyntax.Body)
	if !ok {
		_ = emit(project, "REFUTED", "HCL_TERRAFORM_BODY_UNAVAILABLE", "RESTORE_NATIVE_HCL_TERRAFORM_DECLARATION", "", digest(sourceBytes), values, counts, sourceRange{})
		return
	}

	var selected *hclsyntax.Block
	for _, block := range body.Blocks {
		if block.Type == "resource" && len(block.Labels) == 2 && block.Labels[0] == values.ResourceType && block.Labels[1] == values.ResourceName {
			counts.ResourceBlocks++
			selected = block
		}
	}
	if counts.ResourceBlocks != 1 {
		_ = emit(project, "REFUTED", "HCL_RESOURCE_CARDINALITY_MISMATCH", "RESTORE_UNIQUE_HCL_RESOURCE_BLOCK", "", digest(sourceBytes), values, counts, sourceRange{})
		return
	}

	target, targetPresent, targetResolved := stringAttribute(selected.Body.Attributes["target"])
	imageDigest, digestPresent, digestResolved := stringAttribute(selected.Body.Attributes["image_digest"])
	if targetPresent {
		counts.TargetAttributes = 1
	}
	if digestPresent {
		counts.ImageDigestAttributes = 1
	}
	observedRange := rangeOf(selected.Range())
	if !targetPresent || !digestPresent {
		_ = emit(project, "REFUTED", "HCL_RESOURCE_ATTRIBUTE_MISMATCH", "RESTORE_REQUIRED_HCL_RESOURCE_ATTRIBUTES", "", digest(sourceBytes), values, counts, observedRange)
		return
	}
	if !targetResolved || !digestResolved {
		_ = emit(project, "UNKNOWN", "HCL_RESOURCE_VALUE_UNRESOLVED", "PROVIDE_HCL_EVALUATION_CONTEXT", "CONTEXT_MISSING", digest(sourceBytes), values, counts, observedRange)
		return
	}

	values.Target = target
	values.ImageDigest = imageDigest
	if values.Target != project.DeploymentTarget || values.ImageDigest != project.ArtifactDigest {
		_ = emit(project, "REFUTED", "HCL_RESOURCE_VALUE_MISMATCH", "RESTORE_HCL_RESOURCE_VALUES", "", digest(sourceBytes), values, counts, observedRange)
		return
	}
	if err := emit(project, "CLOSED", "HCL_TERRAFORM_DECLARATION_BOUND", "NONE", "", digest(sourceBytes), values, counts, observedRange); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(74)
	}
}
