# 🌳 Graph Builder (Flutter)

A simple Flutter app to **create and navigate a tree-like graph of nodes**.  
Users can add, delete, and activate nodes in a dynamic graph. The graph is visualized with smooth lines connecting parent and child nodes.

---

## ✨ Features

- Starts with a **single root node** labeled `1`.
- **Tap any node** to make it the active node.
- **Add child nodes** to the active node (labels auto-increment: `2`, `3`, `4`...).
- **Delete nodes**:
  - Deleting a node removes its entire subtree.
  - The root node cannot be deleted.
- Graph visualization:
  - Parent nodes displayed above their children.
  - **Connector lines** drawn between parent and children.
  - Lines use smooth curves to avoid overlap.
- **Active node highlighting** for easy navigation.
- **Maximum depth of 100 levels** enforced.
- **Pan & zoom** support for navigating large trees.

---

## 🎥 Demo

<img width="1916" height="797" alt="image" src="https://github.com/user-attachments/assets/91a2e05d-44c3-4931-b316-edd5f90851d8" />

lib/
 └── main.dart   # Full app code (tree structure, UI, line drawing, interactions)

