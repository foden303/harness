package hostgen

import "github.com/foden303/harness/go/internal/runtimefloor"

// The floor.policy.v1 fragment is the canonical floor policy holding the
// 5-category enum plus each category's human-readable name. It is embedded as
// the same fragment into all 3 host hook JSON files.
type FloorFragment struct {
	Version    string             `json:"version"`
	Categories []FloorCategoryRow `json:"categories"`
}

type FloorCategoryRow struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// FloorPolicyFragment takes the list of runtimefloor.Category values and
// deterministically assembles a FloorFragment. The ID order is fixed (matching
// the definition order of runtimefloor.Category).
func FloorPolicyFragment() FloorFragment {
	return FloorFragment{
		Version: "floor.policy.v1",
		Categories: []FloorCategoryRow{
			{ID: string(runtimefloor.CategoryMoneyBilling), Name: "Money / Billing"},
			{ID: string(runtimefloor.CategoryEgress), Name: "External Network Egress"},
			{ID: string(runtimefloor.CategorySecretRead), Name: "Secret / Credential Read"},
			{ID: string(runtimefloor.CategoryProdDeploy), Name: "Production Deploy"},
			{ID: string(runtimefloor.CategoryWorktreeEscape), Name: "Worktree Escape"},
		},
	}
}
