%{
        #include "common/node.hpp"
        #include <cstdio>
        #include <cstdlib>
        NBlock *programBlock; /* the top level root node of our final AST */
        extern int yylex();
        void yyerror(const char *s) { std::printf("Error: %s\n", s);std::exit(1); }
%}
/* Represents the many different ways we can access our data */
%union {
        Node *node;
        NBlock *block;
        NExpression *expr;
        NStatement *stmt;
        NIdentifier *ident;
        NVariableDeclaration *var_decl;
        std::vector<NVariableDeclaration*> *varvec;
        std::vector<NExpression*> *exprvec;
        std::string *string;
        int token;
}
/* Define our terminal symbols (tokens). This should
   match our tokens.l lex file. We also define the node type
   they represent.
 */
%token <string> TIDENTIFIER TINTEGER TDOUBLE
%token <token> TCEQ TCNE TCLT TCLE TCGT TCGE TEQUAL
%token <token> TLPAREN TRPAREN TLBRACE TRBRACE TCOMMA TDOT
%token <token> TPLUS TMINUS TMUL TDIV
%token <token> TRETURN TEXTERN
/* Define the type of node our nonterminal symbols represent.
   The types refer to the %union declaration above. Ex: when
   we call an ident (defined by union type ident) we are really
   calling an (NIdentifier*). It makes the compiler happy.
 */
%type <ident> ident
%type <expr> numeric call_expr value_expr assign_expr operand_expr
%type <varvec> func_decl_args
%type <exprvec> call_args
%type <block> program stmts block
%type <stmt> stmt var_decl func_decl extern_decl
%type <token> comparison calculation
/* Operator precedence for mathematical operators */
%left TCGE
%left TCGT
%left TCLE
%left TCLT
%left TCNE
%left TCEQ
%left TMINUS
%left TPLUS
%left TDIV
%left TMUL 
%start program
%%
program : stmts { programBlock = $1; }
         ;
                
stmts : stmt { $$ = new NBlock(); $$->statements.push_back($<stmt>1); }
         | stmts stmt { $1->statements.push_back($<stmt>2); }
         ;
stmt : func_decl
         | var_decl
         | extern_decl
         | call_expr { $$ = new NExpressionStatement(*$1); }
         | assign_expr { $$ = new NExpressionStatement(*$1); }
         | TRETURN call_expr { $$ = new NReturnStatement(*$2); }
         | TRETURN value_expr { $$ = new NReturnStatement(*$2); }
         ;
block : TLBRACE stmts TRBRACE { $$ = $2; }
         | TLBRACE TRBRACE { $$ = new NBlock(); }
         ;
var_decl : ident ident { $$ = new NVariableDeclaration(*$1, *$2); }
         | ident ident TEQUAL call_expr { $$ = new NVariableDeclaration(*$1, *$2, $4); }
         | ident ident TEQUAL value_expr { $$ = new NVariableDeclaration(*$1, *$2, $4); }
         ;
extern_decl : TEXTERN ident ident TLPAREN func_decl_args TRPAREN
                { $$ = new NExternDeclaration(*$2, *$3, *$5); delete $5; }
         ;
func_decl : ident ident TLPAREN func_decl_args TRPAREN block 
                        { $$ = new NFunctionDeclaration(*$1, *$2, *$4, *$6); delete $4; }
         ;
        
func_decl_args : /*blank*/  { $$ = new VariableList(); }
         | var_decl { $$ = new VariableList(); $$->push_back($<var_decl>1); }
         | func_decl_args TCOMMA var_decl { $1->push_back($<var_decl>3); }
         ;
ident : TIDENTIFIER { $$ = new NIdentifier(*$1); delete $1; }
         ;
numeric : TINTEGER { $$ = new NInteger(atol($1->c_str())); delete $1; }
         | TDOUBLE { $$ = new NDouble(atof($1->c_str())); delete $1; }
         ;
assign_expr : ident TEQUAL call_expr { $$ = new NAssignment(*$<ident>1, *$3); }
         | ident TEQUAL value_expr { $$ = new NAssignment(*$<ident>1, *$3); }
         ;
call_expr : ident TLPAREN call_args TRPAREN { $$ = new NMethodCall(*$1, *$3); delete $3; }
         ;
operand_expr: call_expr %prec TMUL
         | value_expr %prec TCEQ
         ;
value_expr: ident { $<ident>$ = $1; }
         | numeric
         | TLPAREN value_expr TRPAREN { $$ = $2; }
         | operand_expr calculation operand_expr %prec TMUL { $$ = new NBinaryOperator(*$1, $2, *$3); }
         | operand_expr comparison operand_expr %prec TCEQ { $$ = new NBinaryOperator(*$1, $2, *$3); }
         ;
        
call_args : /*blank*/  { $$ = new ExpressionList(); }
         | value_expr { $$ = new ExpressionList(); $$->push_back($1); }
         | call_expr { $$ = new ExpressionList(); $$->push_back($1); }
         | call_args TCOMMA value_expr  { $1->push_back($3); }
         | call_args TCOMMA call_expr  { $1->push_back($3); }
         ;
comparison : TCEQ | TCNE | TCLT | TCLE | TCGT | TCGE;
calculation: TMUL | TDIV | TPLUS | TMINUS;
%%