module tokenizer;

import std::io;
import std::collections;

enum TokenType : short
{
    // Single-character tokens.
    LEFT_PAREN, RIGHT_PAREN,
    COMMA, DOT, MINUS, PLUS, SLASH, STAR, CARET,

    // Literals.
    NUMBER,

    EOF
}

struct Token
{
    String content;
    TokenType type;
    int location; // index of first character in string
}

def TokenList = List(<Token>);

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
                tokens.push(Token { "(", TokenType.LEFT_PAREN, position } );
                position++;
            case ')':
                tokens.push(Token { ")", TokenType.RIGHT_PAREN, position } );
                position++;
            case ',':
                tokens.push(Token { ",", TokenType.COMMA, position } );
                position++;
            case '.':
                tokens.push(Token { ".", TokenType.DOT, position } );
                position++;
            case '-':
                tokens.push(Token { "-", TokenType.MINUS, position } );
                position++;
            case '+':
                tokens.push(Token { "+", TokenType.PLUS, position } );
                position++;
            case '/':
                tokens.push(Token { "/", TokenType.SLASH, position } );
                position++;
            case '*':
                tokens.push(Token { "*", TokenType.STAR, position } );
                position++;
            case '^':
                tokens.push(Token { "^", TokenType.CARET, position } );
                position++;

            default:
                // numbers
                if (isDigit(current))
                {
                    int numStart = position;
                    while (isDigit(current) || current == '.')
                    {
                        io::printfn("Processing number at position %d (char '%c')", position, current);
                        position++;
                        if (position >= expression.len) break;
                        current = expression[position];
                    }
                    Token number = { expression[numStart .. position - 1], TokenType.NUMBER, numStart };
                    io::printfn("Finished processing number %s", number.content);
                    tokens.push(number);
                    break;
                }
                io::printfn("Unexpected character at position %d ('%c')", position, current);
                return tokens;
        }
    }

    io::print("[ ");
    foreach (idx, &token : tokens)
    {
        io::printf("{ \"%s\", %d, %d }, ", token.content, token.type, token.location);
    }
    io::print("]\n");

    return tokens;
}

fn bool isDigit(char c)
{
    return '0' <= c && c <= '9';
}
