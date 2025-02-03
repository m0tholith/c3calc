module calculator;

import token;

fn int main(String[] args)
{
    TokenList tokens = token::tokenize(args[1]);

    tokens.free();
	return 0;
}
