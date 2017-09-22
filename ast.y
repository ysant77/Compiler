%{
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include "calc3.h"
/* prototypes */
nodeType *opr(int oper, int nops, ...);
nodeType *id(int i);
nodeType *con(int value);
void freeNode(nodeType *p);
int ex(nodeType *p);
int yylex(void);
void yyerror(char *s);
void graphInit (void);
void graphFinish();
void graphBox (char *s, int *w, int *h);
void graphDrawBox (char *s, int c, int l);
void graphDrawArrow (int c1, int l1, int c2, int l2);
/* recursive drawing of the syntax tree */
void exNode (nodeType *p, int c, int l, int *ce, int *cm);
static int lbl;
int sym[26]; /* symbol table */
int del = 1; /* distance of graph columns */
int eps = 3; /* distance of graph lines */
/* interface for drawing (can be replaced by "real" graphic using GD or other) */
%}
%union {
int iValue; /* integer value */
char sIndex; /* symbol table index */
nodeType *nPtr; /* node pointer */
};
%token <iValue> INTEGER
%token <sIndex> VARIABLE
%token WHILE IF PRINT
%nonassoc IFX
%nonassoc ELSE
%left GE LE EQ NE '>' '<'
%left '+' '-'
%left '*' '/'
%nonassoc UMINUS
%type <nPtr> stmt expr stmt_list
%%
program:
function { exit(0); }
;
function:
function stmt { ex($2); freeNode($2); }
| /* NULL */
;
stmt:
';' { $$ = opr(';', 2, NULL, NULL); } | expr ';' { $$ = $1; }
| PRINT expr ';' { $$ = opr(PRINT, 1, $2); } | VARIABLE '=' expr ';' { $$ = opr('=', 2, id($1), $3); }
| WHILE '(' expr ')' stmt { $$ = opr(WHILE, 2, $3, $5); }
| IF '(' expr ')' stmt %prec IFX { $$ = opr(IF, 2, $3, $5); }
| IF '(' expr ')' stmt ELSE stmt
{ $$ = opr(IF, 3, $3, $5, $7); }
| '{' stmt_list '}' { $$ = $2; }
;
stmt_list:
stmt { $$ = $1; }
| stmt_list stmt { $$ = opr(';', 2, $1, $2); }
;
expr:
INTEGER { $$ = con($1); }
| VARIABLE { $$ = id($1); }
| '-' expr %prec UMINUS { $$ = opr(UMINUS, 1, $2); }
| expr '+' expr { $$ = opr('+', 2, $1, $3); } | expr '-' expr { $$ = opr('-', 2, $1, $3); }
| expr '*' expr { $$ = opr('*', 2, $1, $3); }
| expr '/' expr { $$ = opr('/', 2, $1, $3); }
| expr '<' expr { $$ = opr('<', 2, $1, $3); }
| expr '>' expr { $$ = opr('>', 2, $1, $3); }
| expr GE expr { $$ = opr(GE, 2, $1, $3); }
| expr LE expr { $$ = opr(LE, 2, $1, $3); }
| expr NE expr { $$ = opr(NE, 2, $1, $3); }
| expr EQ expr { $$ = opr(EQ, 2, $1, $3); } | '(' expr ')' { $$ = $2; }
;
%%
#define SIZEOF_NODETYPE ((char *)&p->con - (char *)p)
nodeType *con(int value) {
nodeType *p;
/* allocate node */
if ((p = malloc(sizeof(nodeType))) == NULL)
yyerror("out of memory");
/* copy information */
p->type = typeCon;
p->con.value = value;
return p;
}
nodeType *id(int i) {
nodeType *p;
/* allocate node */
if ((p = malloc(sizeof(nodeType))) == NULL)
yyerror("out of memory");
/* copy information */
p->type = typeId;
p->id.i = i;
return p;
}
int ex (nodeType *p) {
int rte, rtm;
graphInit ();
exNode (p, 0, 0, &rte, &rtm); graphFinish();
return 0;
}
/*c----cm---ce----> drawing of leaf-nodes
l leaf-info
*/
/*c---------------cm--------------ce----> drawing of non-leaf-nodes
l node-info
* |
* ------------- ...----
* | | |
* v v v
* child1 child2 ... child-n
* che che che
*cs cs cs cs
*
*/
void exNode
( nodeType *p,
int c, int l, /* start column and line of node */
int *ce, int *cm /* resulting end column and mid of node */
)
{
int w, h; /* node width and height */
char *s; /* node text */
int cbar; /* "real" start column of node (centred above subnodes) */
int k; /* child number */
int che, chm; /* end column and mid of children */
int cs; /* start column of children */
char word[20]; /* extended node text */
if (!p) return;
strcpy (word, "???"); /* should never appear */
s = word;
switch(p->type) {
case typeCon: sprintf (word, "c(%d)", p->con.value); break;
case typeId: sprintf (word, "id(%c)", p->id.i + 'A'); break;
case typeOpr:
switch(p->opr.oper){
case WHILE: s = "while"; break;
case IF: s = "if"; break;
case PRINT: s = "print"; break;
case ';': s = "[;]"; break;
case '=': s = "[=]"; break;
case UMINUS: s = "[_]"; break;
case '+': s = "[+]"; break;
case '-': s = "[-]"; break;
case '*': s = "[*]"; break;
case '/': s = "[/]"; break;
case '<': s = "[<]"; break;
case '>': s = "[>]"; break;
case GE: s = "[>=]"; break;
case LE: s = "[<=]"; break;
case NE: s = "[!=]"; break;
case EQ: s = "[==]"; break;
}
break;
}
/* construct node text box */
graphBox (s, &w, &h);
cbar = c;
*ce = c + w;
*cm = c + w / 2;
/* node is leaf */
if (p->type == typeCon || p->type == typeId || p->opr.nops == 0) {
graphDrawBox (s, cbar, l);
return;
}
/* node has children */
cs = c;
for (k = 0; k < p->opr.nops; k++) {
exNode (p->opr.op[k], cs, l+h+eps, &che, &chm);
cs = che;
}
/* total node width */
if (w < che - c) {
cbar += (che - c - w) / 2; *ce = che;
*cm = (c + che) / 2; }
/* draw node */
graphDrawBox (s, cbar, l);
/* draw arrows (not optimal: children are drawn a second time) */
cs = c;
for (k = 0; k < p->opr.nops; k++) {
exNode (p->opr.op[k], cs, l+h+eps, &che, &chm);
graphDrawArrow (*cm, l+h, chm, l+h+eps-1);
cs = che;
}
}
/* interface for drawing */
#define lmax 200
#define cmax 200
char graph[lmax][cmax]; /* array for ASCII-Graphic */
int graphNumber = 0;
void graphTest (int l, int c)
{ int ok;
ok = 1;
if (l < 0) ok = 0;
if (l >= lmax) ok = 0;
if (c < 0) ok = 0;
if (c >= cmax) ok = 0;
if (ok) return;
printf ("\n+++error: l=%d, c=%d not in drawing rectangle 0, 0 ... %d, %d",
l, c, lmax, cmax);
exit (1);
}
void graphInit (void) { int i, j;
for (i = 0; i < lmax; i++) {
for (j = 0; j < cmax; j++) {
graph[i][j] = ' ';
}
}
}
void graphFinish() {
int i, j;
for (i = 0; i < lmax; i++) {
for (j = cmax-1; j > 0 && graph[i][j] == ' '; j--);
graph[i][cmax-1] = 0;
if (j < cmax-1) graph[i][j+1] = 0;
if (graph[i][j] == ' ') graph[i][j] = 0;
}
for (i = lmax-1; i > 0 && graph[i][0] == 0; i--);
printf ("\n\nGraph %d:\n", graphNumber++);
for (j = 0; j <= i; j++) printf ("\n%s", graph[j]);
printf("\n");
}
void graphBox (char *s, int *w, int *h) {
*w = strlen (s) + del;
*h = 1;
}
void graphDrawBox (char *s, int c, int l) {
int i;
graphTest (l, c+strlen(s)-1+del);
for (i = 0; i < strlen (s); i++) {
graph[l][c+i+del] = s[i];
}
}
void graphDrawArrow (int c1, int l1, int c2, int l2) {
int m;
graphTest (l1, c1);
graphTest (l2, c2);
m = (l1 + l2) / 2;
while (l1 != m) {
graph[l1][c1] = '|'; if (l1 < l2) l1++; else l1--;
}
while (c1 != c2) {
graph[l1][c1] = '-'; if (c1 < c2) c1++; else c1--;
}
while (l1 != l2) {
graph[l1][c1] = '|'; if (l1 < l2) l1++; else l1--;
}
graph[l1][c1] = '|';
}
nodeType *opr(int oper, int nops, ...) {
va_list ap;
nodeType *p;
int i;
/* allocate node, extending op array */
if ((p = malloc(sizeof(nodeType) +
(nops-1) * sizeof(nodeType *))) == NULL)
yyerror("out of memory");
/* copy information */
p->type = typeOpr;
p->opr.oper = oper;
p->opr.nops = nops;
va_start(ap, nops);
for (i = 0; i < nops; i++)
p->opr.op[i] = va_arg(ap, nodeType*);
va_end(ap);
return p;
}
void freeNode(nodeType *p) {
int i;
if (!p) return;
if (p->type == typeOpr) {
for (i = 0; i < p->opr.nops; i++)
freeNode(p->opr.op[i]);
}
free (p);
}
void yyerror(char *s) {
fprintf(stdout, "%s\n", s);
}
int main(int argc,char* argv[]) 
{
extern FILE* yyin;
yyin=fopen(argv[1],"r");
yyparse();
return 0;
}