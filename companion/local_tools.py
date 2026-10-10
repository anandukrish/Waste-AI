"""Small, deterministic offline skills. No eval, shell, network or file access."""
import ast
import datetime
import math
import operator

HELP = (
    "I'm Waste. These commands work without an AI model or internet:\n"
    "/help — show this list\n"
    "/time — show the companion PC's local time\n"
    "/calculate 12 * (3 + 4) — calculate arithmetic\n\n"
    "Notes are saved on your device. Calculator and Notepad can be opened "
    "from Settings after confirmation. For open-ended offline conversation, "
    "install Ollama and download the configured model. Online mode is optional "
    "and never receives your offline chat history automatically."
)


def calculate(expression: str) -> str:
    if not expression.strip() or len(expression) > 200:
        raise ValueError("Use an arithmetic expression of 1–200 characters.")
    try:
        tree = ast.parse(expression, mode="eval")
    except (SyntaxError, RecursionError):
        raise ValueError("Use numbers, parentheses and + - * / // % ** only.") from None
    if sum(1 for _ in ast.walk(tree)) > 70:
        raise ValueError("That expression is too complex.")
    operations = {ast.Add: operator.add, ast.Sub: operator.sub,
                  ast.Mult: operator.mul, ast.Div: operator.truediv,
                  ast.FloorDiv: operator.floordiv, ast.Mod: operator.mod,
                  ast.Pow: operator.pow}

    def visit(node):
        if isinstance(node, ast.Expression):
            return visit(node.body)
        if isinstance(node, ast.Constant) and type(node.value) in (int, float):
            value = node.value
        elif isinstance(node, ast.UnaryOp) and type(node.op) in (ast.UAdd, ast.USub):
            value = visit(node.operand) * (-1 if isinstance(node.op, ast.USub) else 1)
        elif isinstance(node, ast.BinOp) and type(node.op) in operations:
            left, right = visit(node.left), visit(node.right)
            if isinstance(node.op, ast.Pow) and abs(right) > 12:
                raise ValueError("Exponents must be between -12 and 12.")
            value = operations[type(node.op)](left, right)
        else:
            raise ValueError("Only arithmetic is allowed; names and function calls are not.")
        if not isinstance(value, (float, int)) or not math.isfinite(value) or abs(value) > 1e15:
            raise ValueError("Result must be finite and within ±1,000,000,000,000,000.")
        return value

    try:
        return str(visit(tree))
    except (ZeroDivisionError, OverflowError):
        raise ValueError("Cannot divide by zero or calculate an oversized result.") from None


def local_reply(message: str):
    text = message.strip()
    if text == "/help":
        return HELP
    if text == "/time":
        return "Companion PC local time: " + datetime.datetime.now().astimezone().isoformat(timespec="seconds")
    if text == "/calculate" or text.startswith("/calculate "):
        try:
            return "Result: " + calculate(text[len("/calculate"):].strip())
        except ValueError as exc:
            return "Calculation not run: " + str(exc)
    return None
