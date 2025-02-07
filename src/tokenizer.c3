module tokenizer;

import std::io;
import std::collections;

enum TokenType : (inline int value, String name)
{
    LEFT_PAREN   = { 1 << 0, "LEFT_PAREN" },
    RIGHT_PAREN  = { 1 << 1, "RIGHT_PAREN" },
    COMMA        = { 1 << 2, "COMMA" },
    DOT          = { 1 << 3, "DOT" },
    MINUS        = { 1 << 4, "MINUS" },
    PLUS         = { 1 << 5, "PLUS" },
    SLASH        = { 1 << 6, "SLASH" },
    STAR         = { 1 << 7, "STAR" },
    CARET        = { 1 << 8, "CARET" },

    // Literals.
    NUMBER       = { 1 << 9, "NUMBER" },
    WORD         = { 1 << 10, "WORD" },
}

struct Token
{
    String content;
    TokenType type;
    int location; // index of first character in string
}
<*
 @require token != null : "token is null"
 *>
fn bool Token.checkType(Token* token, TokenType type)
{
    if (token.type.value & type.value > 0)
    {
        return true;
    }
    return false;
}
<*
 @require token != null : "token is null"
 *>
fn String Token.toString(Token* token)
{
    DString result;
    result.new_init();
    result.append("{ \"");

    result.append(token.content);
    result.append("\", ");
    result.append(token.type.name);
    result.append(" }");

    String str = result.tcopy_str();
    result.free();

    return str;
}

def TokenList = List(<Token>);

<*
 @require tokens != null : "token list is null"
 *>
fn String TokenList.toString(TokenList* tokens)
{
    DString result;
    result.new_init();
    result.append("[ ");
    foreach (idx, &token : tokens)
    {
        result.append(token.toString());
        result.append(" ");
    }
    result.append("]\n");
    String str = result.tcopy_str();
    result.free();
    return str;
}

<*
 @require expression.len != 0 : "expression is empty"
 *>
fn List(<Token>) tokenize(String expression)
{
    List(<Token>) tokens;
    tokens.new_init();

    int position = 0;

    while (position < expression.len)
    {
        char current = expression[position];
        switch (current)
        {
            // useless space
            case ' ':
            case '\t':
            case '\r':
                position++;
                break;

            // single character
            case '(':
                tokens.push(Token { "(", LEFT_PAREN, position } );
                position++;
            case ')':
                tokens.push(Token { ")", RIGHT_PAREN, position } );
                position++;
            case ',':
                tokens.push(Token { ",", COMMA, position } );
                position++;
            case '.':
                tokens.push(Token { ".", DOT, position } );
                position++;
            case '-':
                tokens.push(Token { "-", MINUS, position } );
                position++;
            case '+':
                tokens.push(Token { "+", PLUS, position } );
                position++;
            case '/':
                tokens.push(Token { "/", SLASH, position } );
                position++;
            case '*':
                tokens.push(Token { "*", STAR, position } );
                position++;
            case '^':
                tokens.push(Token { "^", CARET, position } );
                position++;

            default:
                // numbers
                if (isDigit(current))
                {
                    int numStart = position;
                    while (isDigit(current) || current == '.')
                    {
                        position++;
                        if (position >= expression.len) break;
                        current = expression[position];
                    }
                    Token number = { expression[numStart .. position - 1], NUMBER, numStart };
                    tokens.push(number);
                    break;
                }
				else if (isLetter(current))
				{
					int letterStart = position;
					while (isLetter(current))
					{
						position++;
						if (position >= expression.len) break;
						current = expression[position];
					}
					Token word = { expression[letterStart .. position - 1], WORD, letterStart };
					tokens.push(word);
					break;
				}
                return tokens;
        }
    }

    return tokens;
}

fn bool isDigit(char c)
{
    return '0' <= c && c <= '9';
}
fn bool isLetter(char c)
{
	return ('A' <= c && c <= 'Z') || ('a' <= c && c <= 'z');
}
