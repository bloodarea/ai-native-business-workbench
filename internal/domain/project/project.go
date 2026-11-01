package project

type Item struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}
type Category struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Open     bool   `json:"open"`
	Projects []Item `json:"projects"`
}
type Tree struct {
	Initialized bool       `json:"initialized"`
	Categories  []Category `json:"categories"`
}
