
%option noyywrap stack
%x OUTSIDE PICTURE CLASS_NAME ATTRIBUTES METHODS COMMENT
%x VERBATIM VERB_BAR VERB_PLUS VERB_BANG

%{
#include <stdio.h>
#include <stdlib.h>

/* Estadísticas del análisis */
int nivel_llaves = 0;
int miembro_visible = 0;
int miembro_no_vacio = 0;
int bloque_atributos = 0;
int paquetes = 0;
int profundidad = 0;
int profundidad_maxima = 0;
int atributos_clase_actual = 0;
int atributos_clase_maximos = -1;
char nombre_clase_maxima[256] = "";
char nombre_clase_actual[256] = "";
int publicos = 0;
int privados = 0;
int protegidos = 0;
char miembro[2048];
int longitud_miembro = 0;
int longitud_paquete_maxima = 0;
char nombre_paquete_mas_largo[256] = "ninguno";
char nombre_temporal[256];
void contar_visibilidad(int visibilidad, int es_atributo)
{
    if (visibilidad == '+')
        publicos++;
    else if (visibilidad == '-')
        privados++;
    else if (visibilidad == '#')
        protegidos++;

    if (es_atributo)
        atributos_clase_actual++;
}
void terminar_miembro(int es_atributo)
{
    int i = 0;

    while (i < longitud_miembro &&
           (miembro[i] == ' ' || miembro[i] == '\t' ||
            miembro[i] == '\r' || miembro[i] == '\n'))
        i++;

    if (i < longitud_miembro) {
    contar_visibilidad(miembro[i], es_atributo);
}

    longitud_miembro = 0;
    miembro[0] = '\0';
}
%}

%%
/* Ignorar el entorno verbatim y volver al estado anterior al terminarlo. */
<OUTSIDE,PICTURE,CLASS_NAME,ATTRIBUTES,METHODS>^[ \t]*\\begin\{verbatim\}[^\n]* {
    yy_push_state(VERBATIM);
}

<VERBATIM>\\end\{verbatim\} {
    yy_pop_state();
}

<VERBATIM>(.|\n) ;

/* Ignorar contenido de \verb y \verb* delimitado por |, + o !. */
<OUTSIDE,PICTURE,CLASS_NAME,ATTRIBUTES,METHODS>\\verb\*?\| {
    yy_push_state(VERB_BAR);
}

<OUTSIDE,PICTURE,CLASS_NAME,ATTRIBUTES,METHODS>\\verb\*?\+ {
    yy_push_state(VERB_PLUS);
}

<OUTSIDE,PICTURE,CLASS_NAME,ATTRIBUTES,METHODS>\\verb\*?! {
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
<ATTRIBUTES>\r?\n {
    terminar_miembro(1);
    miembro[0] = '\0';
    longitud_miembro = 0;
}

<METHODS>\r?\n {
    terminar_miembro(0);
    miembro[0] = '\0';
    longitud_miembro = 0;
}    
<PICTURE>"%"[^\n]*       ;
<ATTRIBUTES>"%"[^\n]*    ;
<METHODS>"%"[^\n]*       ;

<OUTSIDE>\\begin[ \t]*\{tikzpicture\}  { BEGIN(PICTURE); }
<OUTSIDE>(.|\n)                         ;

<PICTURE>\\end[ \t]*\{tikzpicture\}     { BEGIN(OUTSIDE); }
<PICTURE>\\begin[ \t]*\{umlpackage\}[ \t]*\{[^{}\n]*\} {
    int i = 0;
    int j = 0;

    paquetes++;
    profundidad++;

    if (profundidad > profundidad_maxima)
        profundidad_maxima = profundidad;

    /* Buscar el inicio del nombre del paquete */
    while (yytext[i] != '}')
    i++;
i++;

while (yytext[i] != '{')
    i++;
i++;
    while (yytext[i] == ' ' || yytext[i] == '\t')
        i++;

    /* Copiar el nombre hasta la llave de cierre */
    while (yytext[i] != '}' && yytext[i] != '\0') {
        if (j < 255)
            nombre_temporal[j++] = yytext[i];
        i++;
    }
    nombre_temporal[j] = '\0';

    /* Conservar el primer nombre más largo */
    if (j > longitud_paquete_maxima) {
        longitud_paquete_maxima = j;
        for (i = 0; i <= j; i++)
            nombre_paquete_mas_largo[i] = nombre_temporal[i];
    }
}
  
<PICTURE>\\end[ \t]*\{umlpackage\} {
    if (profundidad > 0)
        profundidad--;
}	
<PICTURE>\\umlclass {
    nombre_clase_actual[0] = '\0';
    BEGIN(CLASS_NAME);
}
<CLASS_NAME>[ \t\r\n]*\{[ \t\r\n]*[A-Za-z_][A-Za-z0-9_]*[ \t\r\n]*\} {
    int i = 0;
    int j = 0;

    while (yytext[i] != '{')
        i++;
    i++;

    while (yytext[i] == ' ' || yytext[i] == '\t' ||
           yytext[i] == '\r' || yytext[i] == '\n')
        i++;

    while ((yytext[i] >= 'A' && yytext[i] <= 'Z') ||
           (yytext[i] >= 'a' && yytext[i] <= 'z') ||
           (yytext[i] >= '0' && yytext[i] <= '9') ||
           yytext[i] == '_') {
        if (j < 255)
            nombre_clase_actual[j++] = yytext[i];
        i++;
    }
    nombre_clase_actual[j] = '\0';

    longitud_miembro = 0;
    miembro[0] = '\0';
    atributos_clase_actual = 0;
    BEGIN(ATTRIBUTES);
}

<CLASS_NAME>(.|\n) ;
<PICTURE>(.|\n) ;
<ATTRIBUTES>\\end[ \t]*\{tikzpicture\} {
    BEGIN(OUTSIDE);
}

<ATTRIBUTES>\\end[ \t]*\{document\} {
    return 0;
}

<ATTRIBUTES>\\\\ {
    terminar_miembro(1);
    miembro[0] = '\0';
    longitud_miembro = 0;
}

<ATTRIBUTES>\} {
    terminar_miembro(1);

    if (atributos_clase_actual > atributos_clase_maximos) {
        atributos_clase_maximos = atributos_clase_actual;

        int i = 0;
        while (nombre_clase_actual[i] != '\0' && i < 255) {
            nombre_clase_maxima[i] = nombre_clase_actual[i];
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
}            i++;
        }
        nombre_clase_maxima[i] = '\0';
    }

    BEGIN(METHODS);
}

<ATTRIBUTES>\{ {
    /* Ignorar la llave inicial del bloque */
}

<ATTRIBUTES>.|\n {
    if (longitud_miembro < (int)sizeof(miembro) - 1) {
        miembro[longitud_miembro++] = yytext[0];
        miembro[longitud_miembro] = '\0';
    }
}
<METHODS>\\\\ {
    terminar_miembro(0);
    miembro[0] = '\0';
    longitud_miembro = 0;
}

<METHODS>\} {
    terminar_miembro(0);
    BEGIN(PICTURE);
}
<METHODS>\{ {
    /* Ignorar la llave inicial del bloque */
}
<METHODS>.|\n {
    if (longitud_miembro < (int)sizeof(miembro) - 1) {
        miembro[longitud_miembro++] = yytext[0];
        miembro[longitud_miembro] = '\0';
    }
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
