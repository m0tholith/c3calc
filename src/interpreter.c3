module interpreter;

import tokenizer;
import parser;
import std::math;
import std::collections::map;


def FunctionDefinition = fn double(double x);
def FunctionTable = HashMap(<String, FunctionDefinition>);
def VariableTable = HashMap(<String, double>);

struct Interpreter
{
    FunctionTable functions;
    VariableTable variables;
}
fn void Interpreter.new_init(Interpreter* self)
{
    self.functions.new_init();
    self.variables.new_init();
}
fn void Interpreter.add_function(Interpreter* self, String name, FunctionDefinition function)
{
    self.functions.set(name, function);
}
fn void Interpreter.add_variable(Interpreter* self, String name, double variable)
{
    self.variables.set(name, variable);
}
fn String! Interpreter.format(Interpreter* self, String calculation)
{
    TokenList tokens = tokenizer::tokenize(calculation);
    defer tokens.free();

    Expression*! expression = parser::parseExpression(tokens);
    if (catch excuse = expression)
    {
        return excuse?;
    }
    defer expression.free();
    return expression.toString();
}
fn double! Interpreter.evaluate(Interpreter* self, String calculation)
{
    TokenList tokens = tokenizer::tokenize(calculation);
    defer tokens.free();

    Expression*! expression = parser::parseExpression(tokens);
    if (catch excuse = expression)
    {
        return excuse?;
    }
    defer expression.free();
    return expression.evaluate(self);
}
fn void Interpreter.free(Interpreter* self)
{
    self.functions.free();
}

interface ParsingExpression
{
    fn double evaluate(Interpreter* interpreter);
}

<*
 @require self != null : "expression is null"
 *>
fn double Expression.evaluate(Expression* self, Interpreter* interpreter) @dynamic
{
    return self.expr.evaluate(interpreter);
}
<*
 @require self != null : "primary is null"
 *>
fn double Primary.evaluate(Primary* self, Interpreter* interpreter) @dynamic
{
    switch (self.value.type)
    {
        case String.typeid:
            return (*(String*)self.value).to_double()!!;
        case Grouping.typeid:
            return ((Grouping*)self.value).evaluate(interpreter);
    }
    return 999.99999;
}
<*
 @require self != null : "function is null"
 *>
fn double Function.evaluate(Function* self, Interpreter* interpreter) @dynamic
{
    double x = self.primary.evaluate(interpreter);
    if (*self.func == "") return x;
    if (try function = interpreter.functions[*self.func]) return function(x);
    return 999.99999;
}
<*
 @require self != null : "exponent is null"
 *>
fn double Exponent.evaluate(Exponent* self, Interpreter* interpreter) @dynamic
{
	if (self.valueList.len() == 0) return 999.99999;

	double result = self.valueList[^1].evaluate(interpreter);
	for (int i = (int)self.valueList.len() - 1 - 1; i >= 0; i--)
	{
		result = math::pow(self.valueList[i].evaluate(interpreter), result);
	}
	return result;
}
<*
 @require self != null : "unary is null"
 *>
fn double Unary.evaluate(Unary* self, Interpreter* interpreter) @dynamic
{
    switch (self.operator)
    {
        case NONE:
            return self.exponent.evaluate(interpreter);
        case MINUS:
            return -1 * self.exponent.evaluate(interpreter);
    }
}
<*
 @require self != null : "factor is null"
 *>
fn double Factor.evaluate(Factor* self, Interpreter* interpreter) @dynamic
{
    double result = self.left.evaluate(interpreter);
    double unaryEval;
    foreach (idx, unaryRHS : self.right)
    {
        unaryEval = unaryRHS.right.evaluate(interpreter);
        switch (unaryRHS.operator)
        {
            case MUL:
                result *= unaryEval;
            case DIV:
                result /= unaryEval;
        }
    }
    return result;
}
<*
 @require self != null : "term is null"
 *>
fn double Term.evaluate(Term* self, Interpreter* interpreter) @dynamic
{
    double result = self.left.evaluate(interpreter);
    double factorEval;
    foreach (idx, factorRHS : self.right)
    {
        switch (factorRHS.operator)
        {
            case ADD:
                factorEval = +1;
            case SUB:
                factorEval = -1;
        }
        factorEval *= factorRHS.right.evaluate(interpreter);
        result += factorEval;
    }
    return result;
}
<*
 @require self != null : "grouping is null"
 *>
fn double Grouping.evaluate(Grouping* self, Interpreter* interpreter) @dynamic
{
    return self.expr.evaluate(interpreter);
}
<*
 @require self != null : "variable is null"
 *>
fn double Variable.evaluate(Variable* self, Interpreter* interpreter) @dynamic
{
    if (try variable = interpreter.variables[*self.name]) return variable;
    return 999.99999;
}
