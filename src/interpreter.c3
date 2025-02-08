module interpreter;

import tokenizer;
import parser;
import std::math;
import std::collections::map;


def FunctionDefinition = fn double(double x);
def FunctionTable = HashMap(<String, FunctionDefinition>);

struct Interpreter
{
    FunctionTable functions;
}
fn void Interpreter.new_init(Interpreter* self)
{
    self.functions.new_init();
}
fn void Interpreter.add_function(Interpreter* self, String name, FunctionDefinition function)
{
    self.functions.set(name, function);
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
    return expression.evaluate(self.functions);
}
fn void Interpreter.free(Interpreter* self)
{
    self.functions.free();
}

interface ParsingExpression
{
    fn double evaluate(FunctionTable functions);
}

<*
 @require self != null : "expression is null"
 *>
fn double Expression.evaluate(Expression* self, FunctionTable functions) @dynamic
{
    return self.expr.evaluate(functions);
}
<*
 @require self != null : "primary is null"
 *>
fn double Primary.evaluate(Primary* self, FunctionTable functions) @dynamic
{
    switch (self.value.type)
    {
        case String.typeid:
            return (*(String*)self.value).to_double()!!;
        case Grouping.typeid:
            return ((Grouping*)self.value).evaluate(functions);
    }
    return 999.99999;
}
<*
 @require self != null : "function is null"
 *>
fn double Function.evaluate(Function* self, FunctionTable functions) @dynamic
{
    double x = self.primary.evaluate(functions);
    if (*self.func == "") return x;
    if (try function = functions[*self.func]) return function(x);
    return 999.99999;
}
<*
 @require self != null : "exponent is null"
 *>
fn double Exponent.evaluate(Exponent* self, FunctionTable functions) @dynamic
{
	if (self.valueList.len() == 0) return 999.99999;

	double result = self.valueList[^1].evaluate(functions);
	for (int i = (int)self.valueList.len() - 1 - 1; i >= 0; i--)
	{
		result = math::pow(self.valueList[i].evaluate(functions), result);
	}
	return result;
}
<*
 @require self != null : "unary is null"
 *>
fn double Unary.evaluate(Unary* self, FunctionTable functions) @dynamic
{
    switch (self.operator)
    {
        case NONE:
            return self.exponent.evaluate(functions);
        case MINUS:
            return -1 * self.exponent.evaluate(functions);
    }
}
<*
 @require self != null : "factor is null"
 *>
fn double Factor.evaluate(Factor* self, FunctionTable functions) @dynamic
{
    double result = self.left.evaluate(functions);
    double unaryEval;
    foreach (idx, unaryRHS : self.right)
    {
        unaryEval = unaryRHS.right.evaluate(functions);
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
fn double Term.evaluate(Term* self, FunctionTable functions) @dynamic
{
    double result = self.left.evaluate(functions);
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
        factorEval *= factorRHS.right.evaluate(functions);
        result += factorEval;
    }
    return result;
}
<*
 @require self != null : "grouping is null"
 *>
fn double Grouping.evaluate(Grouping* self, FunctionTable functions) @dynamic
{
    return self.expr.evaluate(functions);
}
