module interpreter;

import tokenizer;
import parser;
import std::io;
import std::math;
import std::core::mem;
import std::collections::map;
import std::collections::tuple;

def FunctionDefinition = fn double(double x);
def FunctionTable = HashMap{String, FunctionDefinition};
def VariableTable = HashMap{String, double};

struct Interpreter
{
    FunctionTable functions;
    VariableTable variables;
}
fn void Interpreter.init(Interpreter* self)
{
    self.functions.init(mem);
    self.variables.init(mem);
}
fn void Interpreter.add_function(Interpreter* self, String name, FunctionDefinition function)
{
    self.functions.set(name, function);
}
fn void Interpreter.add_functions(Interpreter* self, Tuple{String, FunctionDefinition}[] functions)
{
    foreach (function : functions)
    {
        self.functions.set(function.first, function.second);
    }
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
<*
 Evaluate a single calculation.
 *>
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
<*
 Evaluate more than one calculation in the same string.
 *>
fn String! Interpreter.execute(Interpreter* self, String calculation, bool only_get_last = false)
{
    TokenList tokens = tokenizer::tokenize(calculation);
    defer tokens.free();

	bool has_eof = false;
	foreach (token : tokens)
	{
		if (token.type == EOF) has_eof = true;
	}
	if (!has_eof)
	{
		DString result;
		result.init(mem);
		defer result.free();

		Expression*! expression = parser::parseExpression(tokens);
		if (catch excuse = expression)
		{
			return excuse?;
		}
		defer expression.free();
		
		result.appendf("%f", expression.evaluate(self)!);

		return result.tcopy_str();
	}

	DString result;
	result.init(mem);
	defer result.free();
	
	int start = 0;
	int end = 0;
	for (; end < tokens.len(); end++)
	{
		if (tokens[end].type == EOF)
		{
			Token[] tokenArr = tokens.to_tarray()[start .. end - 1];
			TokenList evalTokens;
			evalTokens.init(mem);
			defer evalTokens.free();
			evalTokens.add_array(tokenArr);
			
			Expression*! expression = parser::parseExpression(evalTokens);
			if (catch excuse = expression)
			{
				return excuse?;
			}
			defer expression.free();

            if (only_get_last) result.clear();
			result.appendfn("%s -> %f", expression.toString(), expression.evaluate(self)!);

			start = end + 1;
		}
	}

	return result.tcopy_str();
}
fn void Interpreter.free(Interpreter* self)
{
    self.functions.free();
    self.variables.free();
}

fault EvalError
{
	EXPRESSION_INVALID_TYPE,
	PRIMARY_INVALID_TYPE,
	FUNCTION_NOT_FOUND,
	EXPONENT_EMPTY,
	VARIABLE_NOT_FOUND,
}
interface ParsingExpression
{
    fn double! evaluate(Interpreter* interpreter);
}

<*
 @require self != null : "expression is null"
 *>
fn double! Expression.evaluate(Expression* self, Interpreter* interpreter) @dynamic
{
    switch (self.expr.type)
	{
		case Assignment.typeid:
			return ((Assignment*)self.expr).evaluate(interpreter);
		case Term.typeid:
			return ((Term*)self.expr).evaluate(interpreter);
	}
	return EvalError.EXPRESSION_INVALID_TYPE?;
}
<*
 @require self != null : "primary is null"
 *>
fn double! Primary.evaluate(Primary* self, Interpreter* interpreter) @dynamic
{
    switch (self.value.type)
    {
        case String.typeid:
            return (*(String*)self.value).to_double()!!;
        case Grouping.typeid:
            return ((Grouping*)self.value).evaluate(interpreter);
        case Variable.typeid:
            return ((Variable*)self.value).evaluate(interpreter);
    }
    return EvalError.PRIMARY_INVALID_TYPE?;
}
<*
 @require self != null : "function is null"
 *>
fn double! Function.evaluate(Function* self, Interpreter* interpreter) @dynamic
{
    double x = self.primary.evaluate(interpreter)!;
    if (*self.func == "") return x;
    if (try function = interpreter.functions[*self.func]) return function(x);
	io::eprintfn("couldn't find function %s", *self.func);
    return EvalError.FUNCTION_NOT_FOUND?;
}
<*
 @require self != null : "exponent is null"
 *>
fn double! Exponent.evaluate(Exponent* self, Interpreter* interpreter) @dynamic
{
	if (self.valueList.len() == 0) return EvalError.EXPONENT_EMPTY?;

	double result = self.valueList[^1].evaluate(interpreter)!;
	for (int i = (int)self.valueList.len() - 1 - 1; i >= 0; i--)
	{
		result = math::pow(self.valueList[i].evaluate(interpreter)!, result);
	}
	return result;
}
<*
 @require self != null : "unary is null"
 *>
fn double! Unary.evaluate(Unary* self, Interpreter* interpreter) @dynamic
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
fn double! Factor.evaluate(Factor* self, Interpreter* interpreter) @dynamic
{
    double result = self.left.evaluate(interpreter)!;
    double unaryEval;
    foreach (idx, unaryRHS : self.right)
    {
        unaryEval = unaryRHS.right.evaluate(interpreter)!;
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
fn double! Term.evaluate(Term* self, Interpreter* interpreter) @dynamic
{
    double result = self.left.evaluate(interpreter)!;
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
        factorEval *= factorRHS.right.evaluate(interpreter)!;
        result += factorEval;
    }
    return result;
}
<*
 @require self != null : "grouping is null"
 *>
fn double! Grouping.evaluate(Grouping* self, Interpreter* interpreter) @dynamic
{
    return self.expr.evaluate(interpreter);
}
<*
 @require self != null : "variable is null"
 *>
fn double! Variable.evaluate(Variable* self, Interpreter* interpreter) @dynamic
{
    if (try variable = interpreter.variables[*self.name]) return variable;
	io::eprintfn("couldn't find variable %s", *self.name);
    return EvalError.VARIABLE_NOT_FOUND?;
}
<*
 @require self != null : "assignment is null"
 *>
fn double! Assignment.evaluate(Assignment* self, Interpreter* interpreter)
{
	double valueNumber = self.value.evaluate(interpreter)!;
	interpreter.add_variable(*self.variable.name, valueNumber);
	return valueNumber;
}
