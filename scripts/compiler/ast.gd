extends RefCounted

class ASTNode extends RefCounted:
	var type: String = "ASTNode"
	var span
	var resolved_type = null

class Program extends ASTNode:
	var statements: Array = []
	func _init(s = null): type = "Program"; span = s

class VarDecl extends ASTNode:
	var type_name: String
	var identifier: String
	var initializer: ASTNode
	var symbol = null
	func _init(s = null): type = "VarDecl"; span = s

class Assignment extends ASTNode:
	var identifier: String
	var value: ASTNode
	func _init(s = null): type = "Assignment"; span = s

class FunctionDecl extends ASTNode:
	var identifier: String
	var parameters: Array = [] # Array of Dictionary { "name": String, "type": String }
	var return_type: String
	var body: Block
	func _init(s = null): type = "FunctionDecl"; span = s

class Block extends ASTNode:
	var statements: Array = []
	func _init(s = null): type = "Block"; span = s

class IfStmt extends ASTNode:
	var condition: ASTNode
	var then_branch: Block
	var else_branch: Block
	func _init(s = null): type = "IfStmt"; span = s

class WhileStmt extends ASTNode:
	var condition: ASTNode
	var body: Block
	func _init(s = null): type = "WhileStmt"; span = s

class ForEnemyStmt extends ASTNode:
	var identifier: String
	var collection: ASTNode
	var body: Block
	func _init(s = null): type = "ForEnemyStmt"; span = s

class ReturnStmt extends ASTNode:
	var value: ASTNode
	func _init(s = null): type = "ReturnStmt"; span = s

class ExprStmt extends ASTNode:
	var expression: ASTNode
	func _init(s = null): type = "ExprStmt"; span = s

class BinaryExpr extends ASTNode:
	var left: ASTNode
	var operator: int # TokenType
	var right: ASTNode
	func _init(s = null): type = "BinaryExpr"; span = s

class UnaryExpr extends ASTNode:
	var operator: int # TokenType
	var right: ASTNode
	func _init(s = null): type = "UnaryExpr"; span = s

class LiteralExpr extends ASTNode:
	var value: Variant
	var literal_type: int # TokenType (TK_INT_LITERAL, etc)
	func _init(s = null): type = "LiteralExpr"; span = s

class IdentifierExpr extends ASTNode:
	var identifier: String
	var symbol = null
	func _init(s = null): type = "IdentifierExpr"; span = s

class CallExpr extends ASTNode:
	var callee: String
	var arguments: Array = []
	func _init(s = null): type = "CallExpr"; span = s

class MemberAccessExpr extends ASTNode:
	var object: ASTNode
	var member: String
	func _init(s = null): type = "MemberAccessExpr"; span = s
