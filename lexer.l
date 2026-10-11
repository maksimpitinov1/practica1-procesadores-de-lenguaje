
%option noyywrap stack
%x OUTSIDE PICTURE CLASS_WAIT CLASS_OPTIONS CLASS_NAME
%x ATTRIBUTES METHODS PACKAGE_WAIT PACKAGE_OPTIONS PACKAGE_NAME
%x VERBATIM VERB_BAR VERB_PLUS VERB_BANG

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int paquetes = 0;
int profundidad = 0;
int profundidad_maxima = 0;

int publicos = 0;
int privados = 0;
int protegidos = 0;

int nivel_llaves = 0;
int atributos_clase_actual = 0;
int atributos_clase_maximos = -1;

char nombre_clase_actual[256] = "";
char nombre_clase_maxima[256] = "";
char nombre_paquete_mas_largo[256] = "ninguno";
int longitud_paquete_maxima = 0;

char miembro[2048];
int longitud_miembro = 0;
int profundidad_opciones = 0;

static void guardar_caracter(char c)
{
    if (longitud_miembro < (int)sizeof(miembro) - 1) {
        miembro[longitud_miembro++] = c;
        miembro[longitud_miembro] = '\0';
    }
}

static void limpiar_miembro(void)
{
    longitud_miembro = 0;
    miembro[0] = '\0';
}

static void terminar_miembro(int es_atributo)
{
    int i = 0;

    while (i < longitud_miembro &&
           (miembro[i] == ' ' || miembro[i] == '\t' ||
            miembro[i] == '\r' || miembro[i] == '\n'))
        i++;
    if (i < longitud_miembro) {
        if (miembro[i] == '+')
            publicos++;
        else if (miembro[i] == '-')
            privados++;
        else if (miembro[i] == '#')
            protegidos++;

        if (es_atributo)
            atributos_clase_actual++;
    }

    limpiar_miembro();
}
static void comprobar_nuevo_miembro(char c, int es_atributo)
{
    if (c == '+' || c == '-' || c == '#') {
        if (longitud_miembro > 0)
            terminar_miembro(es_atributo);
    }
}
static void guardar_nombre(char *destino, const char *inicio, int longitud)
{
    int n = longitud;

    if (n > 255)
        n = 255;

    memcpy(destino, inicio, (size_t)n);
    destino[n] = '\0';
}
%}

%%

<OUTSIDE,PICTURE,CLASS_WAIT,CLASS_OPTIONS,CLASS_NAME,ATTRIBUTES,METHODS,PACKAGE_WAIT,PACKAGE_OPTIONS,PACKAGE_NAME>^[ \t]*\\begin\{verbatim\}[^\n]* {
    yy_push_state(VERBATIM);
}
<VERBATIM>\\end\{verbatim\} {
    yy_pop_state();
}
<VERBATIM>(.|\n) ;

<OUTSIDE,PICTURE,CLASS_WAIT,CLASS_OPTIONS,CLASS_NAME,ATTRIBUTES,METHODS,PACKAGE_WAIT,PACKAGE_OPTIONS,PACKAGE_NAME>\\verb\*?\| {
    yy_push_state(VERB_BAR);
}
<OUTSIDE,PICTURE,CLASS_WAIT,CLASS_OPTIONS,CLASS_NAME,ATTRIBUTES,METHODS,PACKAGE_WAIT,PACKAGE_OPTIONS,PACKAGE_NAME>\\verb\*?\+ {
    yy_push_state(VERB_PLUS);
}
<OUTSIDE,PICTURE,CLASS_WAIT,CLASS_OPTIONS,CLASS_NAME,ATTRIBUTES,METHODS,PACKAGE_WAIT,PACKAGE_OPTIONS,PACKAGE_NAME>\\verb\*?! {
    yy_push_state(VERB_BANG);
}
<VERB_BAR>[^|]*\| {
    yy_pop_state();
}
<VERB_PLUS>[^+]*\+ {
    yy_pop_state();
}
<VERB_BANG>[^!]*! {
    yy_pop_state();
}

<OUTSIDE,PICTURE,CLASS_WAIT,CLASS_OPTIONS,CLASS_NAME,ATTRIBUTES,METHODS,PACKAGE_WAIT,PACKAGE_OPTIONS,PACKAGE_NAME>"%"[^\n]* ;
<ATTRIBUTES,METHODS>\\% {
    guardar_caracter('%');
}
<CLASS_OPTIONS,PACKAGE_OPTIONS>\\. ;

<OUTSIDE>\\begin[ \t]*\{tikzpicture\} {
    BEGIN(PICTURE);
}
<OUTSIDE>(.|\n) ;

<PICTURE>\\end[ \t]*\{tikzpicture\} {
    BEGIN(OUTSIDE);
}
<PICTURE>\\begin[ \t]*\{umlpackage\} {
    BEGIN(PACKAGE_WAIT);
}
<PICTURE>\\umlclass {
    nombre_clase_actual[0] = '\0';
    BEGIN(CLASS_WAIT);
}
<PICTURE>(.|\n) ;

<PACKAGE_WAIT>[ \t\r\n]+ ;
<PACKAGE_WAIT>"[" {
    profundidad_opciones = 0;
    BEGIN(PACKAGE_OPTIONS);
}
<PACKAGE_OPTIONS>"{" {
    profundidad_opciones++;
}
<PACKAGE_OPTIONS>"}" {
    if (profundidad_opciones > 0)
        profundidad_opciones--;
}
<PACKAGE_OPTIONS>"]" {
    if (profundidad_opciones == 0)
        BEGIN(PACKAGE_WAIT);
}
<PACKAGE_OPTIONS>(.|\n) ;
<PACKAGE_WAIT>"{"[ \t\r\n]*[^{}\n]*"}" {
    int i = 1;
    int fin = yyleng - 1;

    while (i < fin &&
           (yytext[i] == ' ' || yytext[i] == '\t' ||
            yytext[i] == '\r' || yytext[i] == '\n'))
        i++;

    while (fin > i &&
           (yytext[fin - 1] == ' ' || yytext[fin - 1] == '\t' ||
            yytext[fin - 1] == '\r' || yytext[fin - 1] == '\n'))
        fin--;

    paquetes++;
    profundidad++;
    if (profundidad > profundidad_maxima)
        profundidad_maxima = profundidad;

    if (fin - i > longitud_paquete_maxima) {
        longitud_paquete_maxima = fin - i;
        guardar_nombre(nombre_paquete_mas_largo, yytext + i,
                       fin - i);
    }

    BEGIN(PICTURE);
}
<PACKAGE_WAIT>(.|\n) ;

<PICTURE>\\end[ \t]*\{umlpackage\} {
    if (profundidad > 0)
        profundidad--;
}

<CLASS_WAIT>[ \t\r\n]+ ;
<CLASS_WAIT>"[" {
    profundidad_opciones = 0;
    BEGIN(CLASS_OPTIONS);
}
<CLASS_OPTIONS>"{" {
    profundidad_opciones++;
}
<CLASS_OPTIONS>"}" {
    if (profundidad_opciones > 0)
        profundidad_opciones--;
}
<CLASS_OPTIONS>"]" {
    if (profundidad_opciones == 0)
        BEGIN(CLASS_WAIT);
}
<CLASS_OPTIONS>(.|\n) ;

<CLASS_WAIT>"{"[ \t\r\n]*[A-Za-z_][A-Za-z0-9_]*[ \t\r\n]*"}" {
    int i = 1;
    int j = 0;

    while (i < yyleng &&
           (yytext[i] == ' ' || yytext[i] == '\t' ||
            yytext[i] == '\r' || yytext[i] == '\n'))
        i++;

    while (i < yyleng &&
           ((yytext[i] >= 'A' && yytext[i] <= 'Z') ||
            (yytext[i] >= 'a' && yytext[i] <= 'z') ||
            (yytext[i] >= '0' && yytext[i] <= '9') ||
            yytext[i] == '_')) {
        if (j < 255)
            nombre_clase_actual[j++] = yytext[i];
        i++;
    }
    nombre_clase_actual[j] = '\0';

    atributos_clase_actual = 0;
    limpiar_miembro();
    nivel_llaves = 0;
    BEGIN(ATTRIBUTES);
}
<CLASS_WAIT>(.|\n) ;

<ATTRIBUTES>\\[{}] {
    guardar_caracter(yytext[1]);
}
<ATTRIBUTES>\\\\ {
    terminar_miembro(1);
}
<ATTRIBUTES>"{" {
    if (nivel_llaves == 0) {
        nivel_llaves = 1;
    } else {
        nivel_llaves++;
        guardar_caracter('{');
    }
}
<ATTRIBUTES>"}" {
   nivel_llaves--;
    if (nivel_llaves == 0) {
        terminar_miembro(1);

        if (atributos_clase_actual > atributos_clase_maximos) {
            atributos_clase_maximos = atributos_clase_actual;
            strcpy(nombre_clase_maxima, nombre_clase_actual);
        }

        nivel_llaves = 0;
        limpiar_miembro();
        BEGIN(METHODS);
    } else {
        guardar_caracter('}');
    }
}
<ATTRIBUTES>(.|\n) {
    if (nivel_llaves == 1 &&
        (yytext[0] == '+' || yytext[0] == '-' || yytext[0] == '#')) {
        comprobar_nuevo_miembro(yytext[0], 1);
    }
    guardar_caracter(yytext[0]);
}

<METHODS>\\[{}] {
    guardar_caracter(yytext[1]);
}
<METHODS>\\\\ {
    terminar_miembro(0);
}
<METHODS>"{" {
    if (nivel_llaves == 0) {
        nivel_llaves = 1;
    } else {
        nivel_llaves++;
        guardar_caracter('{');
    }
}
<METHODS>"}" {
    nivel_llaves--;
    if (nivel_llaves == 0) {
        terminar_miembro(0);
        nivel_llaves = 0;
        BEGIN(PICTURE);
    } else {
        guardar_caracter('}');
    }
}
<METHODS>(.|\n) {
    if (nivel_llaves == 1 &&
        (yytext[0] == '+' || yytext[0] == '-' || yytext[0] == '#')) {
        comprobar_nuevo_miembro(yytext[0], 0);
    }
    guardar_caracter(yytext[0]);
}

%%

int main(int argc, char **argv)
{
    if (argc > 2) {
        fprintf(stderr, "Uso: %s [archivo.tex]\n", argv[0]);
        return 1;
    }

    if (argc == 2) {
        yyin = fopen(argv[1], "r");
        if (yyin == NULL) {
            perror(argv[1]);
            return 1;
        }
    }

    BEGIN(OUTSIDE);
    yylex();

    if (argc == 2)
        fclose(yyin);
    printf("Paquetes: %d (anidamiento máximo: %d)\n",
           paquetes, profundidad_maxima);
    printf("Miembros por visibilidad: públicos %d, privados %d, protegidos %d\n",
           publicos, privados, protegidos);
    printf("Clase con más atributos: %s (%d)\n",
           nombre_clase_maxima, atributos_clase_maximos);
    printf("Nombre de paquete más largo: %s\n",
           nombre_paquete_mas_largo);

    return 0;
}
