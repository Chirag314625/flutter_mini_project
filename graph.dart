import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:flutter/rendering.dart'; // Import for RenderBox and RenderObject

void main() {
  runApp(const MyApp());
}

// DATA_MODEL
class Node extends ChangeNotifier {
  static int _nextId = 1;
  final int id;
  String _label;
  final List<Node> _children;
  Node? _parent;
  final int level;

  Node({
    required String label,
    required this.level,
    Node? parent,
  })  : id = _nextId++,
        _label = label,
        _children = [],
        _parent = parent;

  String get label => _label;
  List<Node> get children => _children;
  Node? get parent => _parent;

  set label(String newLabel) {
    if (_label == newLabel) return;
    _label = newLabel;
    notifyListeners();
  }

  void addChild(Node child) {
    _children.add(child);
    child._parent = this;
    notifyListeners();
  }

  void removeChild(Node child) {
    _children.removeWhere((Node n) => n.id == child.id);
    child._parent = null;
    notifyListeners();
  }
}

class TreeGraphData extends ChangeNotifier {
  late Node _rootNode;
  Node? _activeNode;

  TreeGraphData() {
    _rootNode = Node(label: "1", level: 0); // Changed from "Root" to "1"
    _activeNode = _rootNode;
  }

  Node get rootNode => _rootNode;
  Node? get activeNode => _activeNode;

  set activeNode(Node? node) {
    if (_activeNode?.id == node?.id) return;
    _activeNode = node;
    notifyListeners();
  }

  void addChildToActiveNode() {
    if (_activeNode == null) return;
    final int newLevel = _activeNode!.level + 1;
    if (newLevel >= 100) {
      return;
    }
    final Node newNode = Node(
      label: "${Node._nextId}",
      level: newLevel,
      parent: _activeNode,
    );
    _activeNode!.addChild(newNode);
    notifyListeners();
  }

  void deleteActiveNode() {
    if (_activeNode == null || _activeNode!.id == _rootNode.id) {
      return;
    }
    final Node? parent = _activeNode!.parent;
    if (parent != null) {
      parent.removeChild(_activeNode!);
      _activeNode = parent;
      notifyListeners();
    }
  }

  void resetTree() {
    Node._nextId = 1; // Reset static ID counter for new nodes
    _rootNode = Node(label: "1", level: 0); // Changed from "Root" to "1"
    _activeNode = _rootNode;
    notifyListeners();
  }

  List<List<Node>> getNodesByLevel() {
    final List<List<Node>> nodesByLevel = [];
    final List<Node> queue = [_rootNode];

    while (queue.isNotEmpty) {
      final int levelSize = queue.length;
      final List<Node> currentLevelNodes = [];

      for (int i = 0; i < levelSize; i++) {
        final Node node = queue.removeAt(0);
        currentLevelNodes.add(node);
        queue.addAll(node.children);
      }
      if (currentLevelNodes.isNotEmpty) {
        nodesByLevel.add(currentLevelNodes);
      }
    }
    return nodesByLevel;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The ChangeNotifierProvider should wrap the entire app to make the
    // TreeGraphData model accessible to all widgets below it in the tree.
    return ChangeNotifierProvider<TreeGraphData>(
      create: (context) => TreeGraphData(),
      child: MaterialApp(
        title: 'Graph Builder', // Changed title
        theme: ThemeData(
          primaryColor: const Color(0xFF673AB7),
          scaffoldBackgroundColor: const Color(0xFF0A0A0F),
          useMaterial3: true,
          brightness: Brightness.dark,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF6C63FF),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), // Made font smaller
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), // Slightly smaller radius
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced padding
              elevation: 4, // Reduced elevation
              shadowColor: const Color(0xFF6C63FF).withOpacity(0.2), // Reduced shadow opacity
            ),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
            titleLarge: TextStyle(color: Colors.white),
          ),
        ),
        home: const TreeGraphPage(),
      ),
    );
  }
}

class TreeGraphPage extends StatefulWidget {
  const TreeGraphPage({super.key});

  @override
  State<TreeGraphPage> createState() => _TreeGraphPageState();
}

class _TreeGraphPageState extends State<TreeGraphPage>
    with TickerProviderStateMixin {
  final Map<int, GlobalKey> _nodeKeys = {};
  Map<int, Offset> _currentNodePositions = {};
  Map<int, Size> _currentNodeSizes = {};
  final GlobalKey _stackKey = GlobalKey();
  late AnimationController _lineAnimationController;

  @override
  void initState() {
    super.initState();
    _lineAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _lineAnimationController.forward();
    
    // Use a post-frame callback to ensure widgets are laid out before getting positions
    WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
      _updateNodePositions();
    });
  }

  @override
  void dispose() {
    _lineAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TreeGraphData treeData = Provider.of<TreeGraphData>(context, listen: false);
    _ensureNodeKeysExist(treeData.rootNode);
  }

  void _ensureNodeKeysExist(Node node) {
    _nodeKeys.putIfAbsent(node.id, () => GlobalKey());
    for (final Node child in node.children) {
      _ensureNodeKeysExist(child);
    }
  }

  bool _mapEquals<K, V>(Map<K, V> map1, Map<K, V> map2) {
    if (map1.length != map2.length) return false;
    for (final MapEntry<K, V> entry in map1.entries) {
      if (!map2.containsKey(entry.key) || entry.value != map2[entry.key]) {
        return false;
      }
    }
    return true;
  }

  void _updateNodePositions() {
    // Only update if the widget is still mounted
    if (!mounted) return;

    final Map<int, Offset> newNodePositions = {};
    final Map<int, Size> newNodeSizes = {};

    final RenderBox? stackRenderBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackRenderBox == null) return;
    
    final Offset stackGlobalPosition = stackRenderBox.localToGlobal(Offset.zero);
    
    for (final MapEntry<int, GlobalKey> nodeEntry in _nodeKeys.entries) {
      final GlobalKey key = nodeEntry.value;
      final RenderBox? nodeRenderBox =
          key.currentContext?.findRenderObject() as RenderBox?;
      if (nodeRenderBox != null) {
        final Offset nodeGlobalPosition = nodeRenderBox.localToGlobal(Offset.zero);
        final Offset relativePositionToStack = nodeGlobalPosition - stackGlobalPosition;

        newNodePositions[nodeEntry.key] = relativePositionToStack;
        newNodeSizes[nodeEntry.key] = nodeRenderBox.size;
      }
    }
    
    if (!_mapEquals<int, Offset>(_currentNodePositions, newNodePositions) ||
        !_mapEquals<int, Size>(_currentNodeSizes, newNodeSizes)) {
      if (mounted) {
        setState(() {
          _currentNodePositions = newNodePositions;
          _currentNodeSizes = newNodeSizes;
        });
        // Restart animation when positions change
        _lineAnimationController.reset();
        _lineAnimationController.forward();
      }
    }
  }

  Widget _buildAdaptiveNodeLayout(List<Node> levelNodes, TreeGraphData treeData) {
    final int nodeCount = levelNodes.length;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double availableWidth = screenWidth - 40; // Account for padding
    
    // Dynamic spacing and sizing calculations
    double nodeSpacing;
    double maxNodeWidth;
    double fontSize;
    EdgeInsets nodePadding;
    
    if (nodeCount <= 2) {
      nodeSpacing = 50.0;
      maxNodeWidth = 150.0;
      fontSize = 18.0;
      nodePadding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    } else if (nodeCount <= 4) {
      nodeSpacing = 30.0;
      maxNodeWidth = 120.0;
      fontSize = 16.0;
      nodePadding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    } else if (nodeCount <= 8) {
      nodeSpacing = 20.0;
      maxNodeWidth = 100.0;
      fontSize = 14.0;
      nodePadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    } else if (nodeCount <= 16) {
      nodeSpacing = 15.0;
      maxNodeWidth = 80.0;
      fontSize = 12.0;
      nodePadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    } else {
      // For very large numbers of nodes
      nodeSpacing = 10.0;
      maxNodeWidth = 60.0;
      fontSize = 10.0;
      nodePadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    }
    
    // Calculate if we need to wrap or use different layout
    final double totalWidthNeeded = (nodeCount * maxNodeWidth) + ((nodeCount - 1) * nodeSpacing);
    
    if (totalWidthNeeded <= availableWidth) {
      // Use Row for better alignment when nodes fit in one line
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: levelNodes.asMap().entries.map<Widget>((entry) {
            final int index = entry.key;
            final Node node = entry.value;
            return Container(
              margin: EdgeInsets.only(left: index > 0 ? nodeSpacing : 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxNodeWidth),
                child: AdaptiveNodeWidget(
                  key: _nodeKeys[node.id],
                  node: node,
                  isActive: node.id == treeData.activeNode?.id,
                  onTap: (tappedNode) => treeData.activeNode = tappedNode,
                  fontSize: fontSize,
                  padding: nodePadding,
                ),
              ),
            );
          }).toList(),
        ),
      );
    } else {
      // Use Wrap for multiple rows when nodes don't fit
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: nodeSpacing,
        runSpacing: 20,
        children: levelNodes.map<Widget>((Node node) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxNodeWidth),
            child: AdaptiveNodeWidget(
              key: _nodeKeys[node.id],
              node: node,
              isActive: node.id == treeData.activeNode?.id,
              onTap: (tappedNode) => treeData.activeNode = tappedNode,
              fontSize: fontSize,
              padding: nodePadding,
            ),
          );
        }).toList(),
      );
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TreeGraphData treeData = Provider.of<TreeGraphData>(context);
    final List<List<Node>> nodesByLevel = treeData.getNodesByLevel();
    
    _ensureNodeKeysExist(treeData.rootNode);
    final Set<int> existingNodeIds = {};
    for (final List<Node> levelNodes in nodesByLevel) {
      for (final Node node in levelNodes) {
        existingNodeIds.add(node.id);
      }
    }
    // Remove keys for nodes that no longer exist in the tree
    _nodeKeys.keys.toList().forEach((keyId) {
      if (!existingNodeIds.contains(keyId)) {
        _nodeKeys.remove(keyId);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
      _updateNodePositions();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Graph Builder', // Changed title
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            ),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12.0), // Reduced padding
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0F)],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (treeData.activeNode == null) {
                        _showSnackbar("No active node to add child to.");
                        return;
                      }
                      if (treeData.activeNode!.level >= 99) {
                        _showSnackbar("Maximum depth reached for adding children.");
                        return;
                      }
                      treeData.addChildToActiveNode();
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 18), // Smaller icon
                    label: const Text('Add Child', style: TextStyle(fontSize: 12)), // Smaller text
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Reduced padding
                      elevation: 4, // Reduced elevation
                    ),
                  ),
                ),
                const SizedBox(width: 8), // Reduced spacing
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (treeData.activeNode == null || treeData.activeNode!.id == treeData.rootNode.id) {
                        _showSnackbar("Cannot delete the root node or no node selected.");
                        return;
                      }
                      treeData.deleteActiveNode();
                    },
                    icon: const Icon(Icons.remove_circle_outline, size: 18), // Smaller icon
                    label: const Text('Delete Node', style: TextStyle(fontSize: 12)), // Smaller text
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      shadowColor: const Color(0xFFFF6B6B).withOpacity(0.2), // Reduced shadow opacity
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Reduced padding
                      elevation: 4, // Reduced elevation
                    ),
                  ),
                ),
                const SizedBox(width: 8), // Reduced spacing
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      treeData.resetTree();
                      _showSnackbar("Tree reset to initial state.");
                    },
                    icon: const Icon(Icons.refresh, size: 18), // Smaller icon
                    label: const Text('Reset', style: TextStyle(fontSize: 12)), // Smaller text
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50), // Green color for reset
                      shadowColor: const Color(0xFF4CAF50).withOpacity(0.2), // Reduced shadow opacity
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Reduced padding
                      elevation: 4, // Reduced elevation
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0F)],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Stack(
                  key: _stackKey,
                  children: <Widget>[
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _lineAnimationController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: EnhancedTreeGraphLinePainter(
                              nodesByLevel: nodesByLevel,
                              nodePositions: _currentNodePositions,
                              nodeSizes: _currentNodeSizes,
                              animationValue: _lineAnimationController.value,
                              activeNodeId: treeData.activeNode?.id,
                            ),
                          );
                        },
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: nodesByLevel.asMap().entries.map<Widget>((entry) {
                        final int levelIndex = entry.key;
                        final List<Node> levelNodes = entry.value;
                        
                        return Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: levelIndex == 0 ? 20.0 : 40.0,
                            horizontal: 20.0,
                          ),
                          child: Center(
                            child: _buildAdaptiveNodeLayout(levelNodes, treeData),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: treeData.activeNode != null
                ? Container(
                    key: ValueKey<int>(treeData.activeNode!.id),
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Active Node',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          treeData.activeNode!.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Level ${treeData.activeNode!.level}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class AdaptiveNodeWidget extends StatefulWidget {
  final Node node;
  final bool isActive;
  final ValueChanged<Node> onTap;
  final double fontSize;
  final EdgeInsets padding;

  const AdaptiveNodeWidget({
    required super.key,
    required this.node,
    required this.isActive,
    required this.onTap,
    required this.fontSize,
    required this.padding,
  });

  @override
  State<AdaptiveNodeWidget> createState() => _AdaptiveNodeWidgetState();
}

class _AdaptiveNodeWidgetState extends State<AdaptiveNodeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AdaptiveNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate dynamic border radius based on font size
    final double borderRadius = widget.fontSize + 5;
    
    return GestureDetector(
      onTap: () => widget.onTap(widget.node),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isActive ? _pulseAnimation.value : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              padding: widget.padding,
              constraints: BoxConstraints(
                minWidth: widget.fontSize * 3,
                minHeight: widget.fontSize * 2.5,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isActive
                      ? [
                          const Color(0xFF6C63FF),
                          const Color(0xFF9C88FF),
                          const Color(0xFF6C63FF),
                        ]
                      : [
                          const Color(0xFF2E2E48),
                          const Color(0xFF3A3A5C),
                          const Color(0xFF2A2A44),
                        ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.4),
                          spreadRadius: 2,
                          blurRadius: widget.fontSize,
                          offset: Offset(0, widget.fontSize * 0.4),
                        ),
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: widget.fontSize * 1.5,
                          offset: Offset(0, widget.fontSize * 0.2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: widget.fontSize * 0.4,
                          offset: Offset(0, widget.fontSize * 0.2),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: widget.fontSize,
                          offset: Offset(0, widget.fontSize * 0.4),
                        ),
                      ],
                border: widget.isActive
                    ? Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      )
                    : null,
              ),
              child: Center(
                child: Text(
                  widget.node.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w600,
                    fontSize: widget.isActive ? widget.fontSize + 1 : widget.fontSize,
                    shadows: widget.isActive
                        ? [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class EnhancedTreeGraphLinePainter extends CustomPainter {
  final List<List<Node>> nodesByLevel;
  final Map<int, Offset> nodePositions;
  final Map<int, Size> nodeSizes;
  final double animationValue;
  final int? activeNodeId;

  EnhancedTreeGraphLinePainter({
    required this.nodesByLevel,
    required this.nodePositions,
    required this.nodeSizes,
    required this.animationValue,
    this.activeNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Create gradient colors for lines
    final List<Color> gradientColors = [
      const Color(0xFF6C63FF),
      const Color(0xFF9C88FF),
      const Color(0xFF78D9FF),
      const Color(0xFF4ECDC4),
    ];

    for (int levelIndex = 0; levelIndex < nodesByLevel.length; levelIndex++) {
      final List<Node> currentLevelNodes = nodesByLevel[levelIndex];
      
      for (final Node parentNode in currentLevelNodes) {
        if (parentNode.children.isEmpty) continue;

        final Offset? parentPosition = nodePositions[parentNode.id];
        final Size? parentSize = nodeSizes[parentNode.id];

        if (parentPosition == null || parentSize == null) continue;

        final bool isActiveNodeConnection = parentNode.id == activeNodeId ||
            parentNode.children.any((child) => child.id == activeNodeId);

        // Get color based on level and active state
        Color lineColor = isActiveNodeConnection
            ? gradientColors[0]
            : gradientColors[levelIndex % gradientColors.length];
        
        final double baseStrokeWidth = isActiveNodeConnection ? 4.0 : 2.5;
        final double strokeWidth = baseStrokeWidth * animationValue;

        // Draw enhanced curved connections
        _drawEnhancedConnection(
          canvas,
          parentNode,
          parentPosition,
          parentSize,
          lineColor,
          strokeWidth,
          isActiveNodeConnection,
        );
      }
    }
  }

  void _drawEnhancedConnection(
    Canvas canvas,
    Node parentNode,
    Offset parentPosition,
    Size parentSize,
    Color lineColor,
    double strokeWidth,
    bool isActive,
  ) {
    final Offset parentBottomCenter = Offset(
      parentPosition.dx + parentSize.width / 2,
      parentPosition.dy + parentSize.height,
    );

    // Get all child positions
    final List<MapEntry<Node, Offset>> childrenWithPositions = parentNode.children
        .map<MapEntry<Node, Offset>?>((child) {
          final Offset? childPos = nodePositions[child.id];
          final Size? childSize = nodeSizes[child.id];
          if (childPos != null && childSize != null) {
            return MapEntry<Node, Offset>(
              child,
              Offset(childPos.dx + childSize.width / 2, childPos.dy),
            );
          }
          return null;
        })
        .whereType<MapEntry<Node, Offset>>()
        .toList();

    if (childrenWithPositions.isEmpty) return;

    // Create paint with gradient effect
    final Paint linePaint = Paint()
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Add glow effect for active connections
    if (isActive) {
      final Paint glowPaint = Paint()
        ..color = lineColor.withOpacity(0.3)
        ..strokeWidth = strokeWidth * 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      
      // Draw glow effect
      for (final MapEntry<Node, Offset> childEntry in childrenWithPositions) {
        final Path path = _createCurvedPath(parentBottomCenter, childEntry.value);
        canvas.drawPath(path, glowPaint);
      }
    }

    // Draw main curved lines
    for (int i = 0; i < childrenWithPositions.length; i++) {
      final MapEntry<Node, Offset> childEntry = childrenWithPositions[i];
      final Offset childTopCenter = childEntry.value;

      // Create gradient shader for each line
      final Rect lineRect = Rect.fromPoints(parentBottomCenter, childTopCenter);
      linePaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withOpacity(0.8),
          lineColor,
          lineColor.withOpacity(0.9),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(lineRect);

      // Create and draw curved path
      final Path curvePath = _createCurvedPath(parentBottomCenter, childTopCenter);
      
      // Apply animation effect by trimming the path
      if (animationValue < 1.0) {
        final PathMetrics pathMetrics = curvePath.computeMetrics();
        final Path animatedPath = Path();
        
        for (final PathMetric pathMetric in pathMetrics) {
          final double pathLength = pathMetric.length;
          final Path extractedPath = pathMetric.extractPath(
            0,
            pathLength * animationValue,
          );
          animatedPath.addPath(extractedPath, Offset.zero);
        }
        canvas.drawPath(animatedPath, linePaint);
      } else {
        canvas.drawPath(curvePath, linePaint);
      }

      // Add decorative elements for active connections
      if (isActive && animationValue > 0.7) {
        _drawConnectionDecorations(canvas, parentBottomCenter, childTopCenter, lineColor);
      }
    }
  }

  Path _createCurvedPath(Offset start, Offset end) {
    final Path path = Path();
    path.moveTo(start.dx, start.dy);

    // Calculate control points for smooth S-curve
    final double midY = start.dy + (end.dy - start.dy) * 0.6;
    final double controlOffset = (end.dx - start.dx).abs() * 0.3;
    
    final Offset control1 = Offset(
      start.dx + (start.dx < end.dx ? controlOffset : -controlOffset),
      midY - 20,
    );
    
    final Offset control2 = Offset(
      end.dx + (start.dx < end.dx ? -controlOffset : controlOffset),
      midY + 20,
    );

    // Create smooth cubic bezier curve
    path.cubicTo(
      control1.dx, control1.dy,
      control2.dx, control2.dy,
      end.dx, end.dy,
    );

    return path;
  }

  void _drawConnectionDecorations(Canvas canvas, Offset start, Offset end, Color color) {
    // Draw small animated dots along the connection
    final Paint dotPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final double distance = (end - start).distance;
    final int numDots = (distance / 50).round().clamp(2, 6);
    
    for (int i = 1; i < numDots; i++) {
      final double t = i / numDots;
      final Offset dotPos = Offset.lerp(start, end, t)!;
      
      // Add slight offset for more organic feel
      final double offset = sin(t * pi * 4) * 5;
      final Offset adjustedPos = Offset(dotPos.dx + offset, dotPos.dy);
      
      canvas.drawCircle(adjustedPos, 2.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant EnhancedTreeGraphLinePainter oldDelegate) {
    return oldDelegate.nodePositions != nodePositions ||
        oldDelegate.nodeSizes != nodeSizes ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.activeNodeId != activeNodeId;
  }
}