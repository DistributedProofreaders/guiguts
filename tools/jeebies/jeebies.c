/*************************************************************************/
/*                                                                       */
/* jeebies  check for common scannos in a PG candidate file              */
/*                                                                       */
/* Version 0.15 (alpha-20051128).                                        */
/* Copyright 2000-2005 Jim Tinsley <jtinsley@pobox.com>                  */
/*                                                                       */
/* This program is free software; you can redistribute it and/or modify  */
/* it under the terms of the GNU General Public License as published by  */
/* the Free Software Foundation; either version 2 of the License, or     */
/* (at your option) any later version.                                   */
/*                                                                       */
/* This program is distributed in the hope that it will be useful,       */
/* but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/* GNU General Public License for more details.                          */
/*                                                                       */
/* You should have received a copy of the GNU General Public License     */
/* along with this program; if not, write to the                         */
/*      Free Software Foundation, Inc.,                                  */
/*      59 Temple Place,                                                 */
/*      Suite 330,                                                       */
/*      Boston, MA  02111-1307  USA                                      */
/*                                                                       */
/*                                                                       */
/*                                                                       */
/*************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define MAXWORDLEN    50    /* max length of one word             */
#define LINEBUFSIZE 2048    /* buffer size for an input line      */
#define USERSCANNO_FILE "jeebies.typ"

#ifndef MAX_PATH
#define MAX_PATH 16384
#endif

// Pointers are assumed to have the same value in binary_search.
// May need to change at some point, which will need change there.
#define HE_POINTERS 80000
#define BE_POINTERS 80000

#define HE_FILE "he.jee"
#define BE_FILE "be.jee"

char aline[LINEBUFSIZE];
char prevline[LINEBUFSIZE];
char *he_array[HE_POINTERS];
char *be_array[BE_POINTERS];

#define PASTWORDS 30

char tword[4][MAXWORDLEN];

long linecnt;         /* count of total lines in the file */

                   
/* ---- list of special characters ---- */
#define CHAR_SPACE        32
#define CHAR_TAB           9
#define CHAR_LF           10
#define CHAR_CR           13
#define CHAR_DQUOTE       34
#define CHAR_SQUOTE       39
#define CHAR_OPEN_SQUOTE  96
#define CHAR_TILDE       126
#define CHAR_ASTERISK     42

#define CHAR_UNDERSCORE    '_'
#define CHAR_OPEN_CBRACK   '{'
#define CHAR_CLOSE_CBRACK  '}'
#define CHAR_OPEN_RBRACK   '('
#define CHAR_CLOSE_RBRACK  ')'
#define CHAR_OPEN_SBRACK   '['
#define CHAR_CLOSE_SBRACK  ']'


#define SWITCHES "PTED"         /* switches:-                                     */
                                /*  P = paranoid -- report even unlikely cases    */
                                /*  T = tolerant -- report only very likely cases */
                                /*  E = don't echo lines                          */
                                /*  D = print Debug values                        */

#define SWITNO 4                /* max number of switch parms                     */
                                /*        - used for defining array-size          */
#define MINARGS   1             /* minimum no of args excl switches               */
#define MAXARGS   1             /* maximum no of args excl switches               */

int pswit[SWITNO];              /* program switches set by SWITCHES               */

#define PARANOID_SWITCH   0
#define TOLERANT_SWITCH   1
#define ECHO_SWITCH       2
#define DEBUG_SWITCH      3

#define START 0
#define END 1
#define PREV 0
#define NEXT 1
#define FIRST_OF_PAIR 0
#define SECOND_OF_PAIR 1

#define MAX_WORDPAIR 1000
#define MAX_ENTRY_LEN 120

char running_from[MAX_PATH];

void proghelp(void);
void procfile(char *);

char *getaword(char *, char *);
char *getawordwithpunct(char *, char *);
int matchword(char *, char *);
char *flgets(char *, int, FILE *, long);
void lowerit(char *);
int gcisalpha(unsigned char);
int gcisdigit(unsigned char);
int gcispunct(unsigned char);
char *gcstrchr(char *s, char c);
double binary_search(char *, char **, long);

long he_count, be_count, total_he, total_be;
char wrk[LINEBUFSIZE];
double runmatch(int which_wordpair, int which_word, int prev_next, char *thisword);

char wordpair[MAX_WORDPAIR][2][20];
long wordpair_pointer[MAX_WORDPAIR][2][2][2];
int which_of_pair, wordpair_count;


int main(int argc, char **argv)
{
    char *argsw;
    int i, switno, invarg;
    char data_filename[MAX_PATH];
    FILE *data_filehandle;
    char *s;

    if (strlen(argv[0]) < sizeof(running_from))
        strcpy(running_from, argv[0]);  /* save the path to the executable jeebies */

    /* find out what directory we're running from */
    for (s = running_from + strlen(running_from); *s != '/' && *s != '\\' && s >= running_from; s--)
        *s = 0;



    switno = strlen(SWITCHES);
    for (i = switno ; --i >0 ; )
        pswit[i] = 0;           /* initialise switches */

    /* Standard loop to extract switches.                   */
    /* When we come out of this loop, the arguments will be */
    /* in argv[0] upwards and the switches used will be     */
    /* represented by their equivalent elements in pswit[]  */
    while ( --argc > 0 && **++argv == '-')
        for (argsw = argv[0]+1; *argsw !='\0'; argsw++)
            for (i = switno, invarg = 1; (--i >= 0) && invarg == 1 ; )
                if ((toupper(*argsw)) == SWITCHES[i] ) {
                    invarg = 0;
                    pswit[i] = 1;
                    }

    if (argc < MINARGS || argc > MAXARGS) {  /* check number of args */
        proghelp();
        return(1);            /* exit */
        }

    fprintf(stderr, "jeebies: find he/be scannos in an e-text\n");
    if (pswit[PARANOID_SWITCH] & pswit[TOLERANT_SWITCH]) {
        fprintf(stderr, "\njeebies: You can't be Tolerant if you're Paranoid! Aborting. \n\n");
        proghelp();
        return(1);            /* exit */
        }
        

    if ((data_filehandle = fopen(HE_FILE, "rb")) == NULL) {
        strcpy(data_filename, running_from);
        strcat(data_filename, HE_FILE);
        if ((data_filehandle = fopen(data_filename, "rb")) == NULL) {  /* we ain't got no user typo file! */
            printf("   --> I couldn't find %s. Aborting.\n", HE_FILE);
            exit(1);
            }
        }

    he_count = 0;
    while (flgets(aline, LINEBUFSIZE-1, data_filehandle, he_count)) {
        if (strlen(aline) > 1) {
            if ((int)*aline > 33) {
                s = malloc(strlen(aline)+1);
                if (!s) {
                    fprintf(stderr, "jeebies: cannot get enough memory for user scanno file. Aborting. \n");
                    exit(1);
                    }
                strcpy(s, aline);
                he_array[he_count] = s;
                he_count++;
                }
            }
        }
    fclose(data_filehandle);

    if ((data_filehandle = fopen(BE_FILE, "rb")) == NULL) {
        strcpy(data_filename, running_from);
        strcat(data_filename, BE_FILE);
        if ((data_filehandle = fopen(data_filename, "rb")) == NULL) {  /* we ain't got no user typo file! */
            printf("   --> I couldn't find %s. Aborting.\n", BE_FILE);
            exit(1);
            }
        }

    be_count = 0;
    while (flgets(aline, LINEBUFSIZE-1, data_filehandle, be_count)) {
        if (strlen(aline) > 1) {
            if ((int)*aline > 33) {
                s = malloc(strlen(aline)+1);
                if (!s) {
                    fprintf(stderr, "jeebies: cannot get enough memory for user scanno file!!\n");
                    exit(1);
                    }
                strcpy(s, aline);
                be_array[be_count] = s;
                be_count++;
                }
            }
        }
    fclose(data_filehandle);

    procfile(argv[0]);

    return(0);
}



/* procfile - process one file */

void procfile(char *filename)
{

    char *s, *t, laststart;
    char inword[MAXWORDLEN], testword[MAXWORDLEN], alt_word[MAXWORDLEN];
    char preword[MAXWORDLEN][PASTWORDS];
    FILE *infile;
    signed int i, isemptyline;
    unsigned int have_alt;

    double he_score, be_score, be_score_adjusted;
    double alt_he_score, alt_be_score;         
    double alt_convince_ratio, convince_ratio;
    double threshold;
    
    double this_file_he_be_ratio;


    laststart = CHAR_SPACE;

    i = isemptyline = 0;
    *inword = *testword = 0;
    alt_convince_ratio = convince_ratio = 0.0;
    he_score = be_score = be_score_adjusted = 0.0;
    alt_he_score =  alt_be_score = 0.0;

    for (i = 0; i < PASTWORDS; i++)
        *preword[i] = 0; 


    fprintf(stdout, "\n\nFile: %s\n\n", filename);

    total_he = total_be = 0;
    if ((infile = fopen(filename, "rb")) == NULL) {
        fprintf(stdout, "jeebies: cannot open %s\n", filename);
        exit(1);
        }
    while (flgets(aline, LINEBUFSIZE-1, infile, linecnt+1)) {
        lowerit(aline);
        for (s = aline; *s;) {
            s = getaword(s, inword);
            if (!*inword) continue; /* don't bother with empty lines */
            if (!strcmp(inword, "he"))
                total_he++;
            if (!strcmp(inword, "be"))
                total_be++;
            }
        }
    fclose (infile);

    if (total_he == 0 && total_be == 0) {
        printf("   --> Odd file. There are neither \"he\"s nor \"be\"s. Abandoning.\n\n");
        exit(1);
        }

    if (total_he > 0 && total_be > 0) {
        this_file_he_be_ratio = (double) total_he / (double) total_be;
        printf("   --> There are %ld \"be\"s and %ld \"he\"s. Calibrating...\n\n", total_be, total_he);
        if (this_file_he_be_ratio > 1000.0) this_file_he_be_ratio = 1000.0;
        if (this_file_he_be_ratio < 1.0/1000.0) this_file_he_be_ratio = 1.0/1000.0;
        }

    if (total_he == 0 && total_be > 0) {
        printf("   --> Odd file. There are %ld \"be\"s and no \"he\"s.\n\n", total_be, total_he);
        this_file_he_be_ratio = 1000.0;
        }

    if (total_he > 0 && total_be == 0) {
        printf("   --> Odd file. There are %ld \"he\"s and no \"be\"s.\n\n", total_he, total_be);
        this_file_he_be_ratio = 1.0/1000.0;
        }
        


    if ((infile = fopen(filename, "rb")) == NULL) {
        fprintf(stdout, "jeebies: cannot open %s\n", filename);
        exit(1);
        }


    threshold = 1.0;
    if (pswit[PARANOID_SWITCH])
        threshold = 0.5;
    if (pswit[TOLERANT_SWITCH])
        threshold = 6.0;

    while (flgets(aline, LINEBUFSIZE-1, infile, linecnt+1)) {
        linecnt++;
        s = t = aline;
        isemptyline = 1;      /* assume the line is empty until proven otherwise */
        while (*s) {
            if (*s != CHAR_SPACE
                && *s != '-'
                && *s != '.'
                && *s != CHAR_ASTERISK
                && *s != 13
                && *s != 10) isemptyline = 0;  /* ignore lines like  *  *  *  as spacers */
                s++;
            }
        if (isemptyline) {
            *tword[1] = *tword[2] = *tword[3] = 0;
            for (i = 0; i < PASTWORDS; i++)
                *preword[i] = 0;
            }

        for (s = aline, t = aline; *s;) {
            if (*s == '.' || *s == '?' || *s == '!'
                || *s == ',' || *s == ';' || *s == ':' 
                || *s == '-' && *(s+1) == '-') 
                *tword[1] = *tword[2] = *tword[3] = 0;
            if (*s == '.' || *s == '?' || *s == '!'
                || *s == ';' || *s == ':' 
                || *s == '-' && *(s+1) == '-') // any of them except a comma!
                for (i = 0; i < PASTWORDS; i++)
                    *preword[i] = 0; 
            s = getaword(s, inword);
            for (i = 0; i < PASTWORDS-1; i++)
                strcpy(preword[i], preword[i+1]);
            t = getawordwithpunct(t, preword[29]);
            if (!*inword) continue; /* don't bother with empty lines */
            strcpy(tword[1], tword[2]);
            strcpy(tword[2], tword[3]);
            strcpy(tword[3], inword);
            if (!strcmp(tword[2], "he") || !strcmp(tword[2], "be")) {
                he_score = be_score = 0.0;  // hygiene. clean them all first
                alt_he_score = alt_be_score = 0.0;
                alt_convince_ratio = convince_ratio = 0.0;
                have_alt = 0; *alt_word = 0;
                // if (the first word before this ends with a comma)
                if (*(preword[27] + strlen(preword[27]) - 1) == ',') {
                    // launch into the clause-checking routine 
                    // Example of preword 27-29 at this point: " not, be queried "
                    s = s;   // DUMMY LINE for BREAKPOINT - remove when done testing
                    // Walk back through preceding words, looking for more commas
                    for (i = 26; i >=0 && *preword[i]; i--) {
                        if (*(preword[i] + strlen(preword[i]) - 1) == ',') {
                            // we have the word before a previous clause!
                            strcpy(alt_word, preword[i]);
                            alt_word[strlen(alt_word) - 1] = 0;
                            alt_he_score = alt_be_score = 0.0;
                            *wrk = 0;
                            strcpy(wrk, alt_word);
                            strcat(wrk, "|he|");
                            strcat(wrk, tword[3]);
                            strcat(wrk, "\t");
                            lowerit(wrk);
                            alt_he_score = binary_search(wrk, he_array, he_count);
                            *wrk = 0;
                            strcpy(wrk, alt_word);
                            strcat(wrk, "|be|");
                            strcat(wrk, tword[3]);
                            strcat(wrk, "\t");
                            lowerit(wrk);
                            alt_be_score = binary_search(wrk, be_array, be_count);
                            }
                        }
                    }
                // Working comment: 
                // OK, I've got alternate scores if there was a comma, which resulted in a no-first-word case.
                //      AND if there was a clause before
                //      (like "it might, alternatively, be said, where wrk is going to be "|be|said")
                //      (so I now have the alt scores for "might be said" and "might he said")
                // Now, what do I usefully do with them as compared to the actual scores?
                // Option 1. Use the "alts" always, and disregard the no-first-word case?
                // Option 2. Use the "alts" only if no no-first-word case is found. No.
                // Option 3. Use the "alts" only if the sum of the alt cases > sum of the no-first-word cases?
                //           Interesting. Maybe the absolute right answer, if my corpus had been
                //           collected that way in the first place. Maybe the best current answer anyway. 
                // Option 4. Query the phrase if _either_ the alt or the no-first-word case qualifies?
                //           Hmmm. That sounds good for paranoid mode, at least.
                // Hmmm. Does dialog, like "'And if you can, then go,' he said." mess all this up?
                *wrk = 0;
                strcpy(wrk, tword[1]);
                strcat(wrk, "|he|");
                strcat(wrk, tword[3]);
                strcat(wrk, "\t");
                lowerit(wrk);
                he_score = binary_search(wrk, he_array, he_count);
                *wrk = 0;
                strcpy(wrk, tword[1]);
                strcat(wrk, "|be|");
                strcat(wrk, tword[3]);
                strcat(wrk, "\t");
                lowerit(wrk);
                be_score = binary_search(wrk, be_array, be_count);

                have_alt = (alt_he_score + alt_be_score > 0.0) ? 1 : 0;

                if (pswit[DEBUG_SWITCH]) {
                    printf(">  %s %s %s  He:%.4lf Be:%.4lf Ratio: %.4lf Threshold: %.2lf \n", tword[1], tword[2], tword[3], he_score, be_score, this_file_he_be_ratio, threshold); 
                    if (have_alt)
                        printf(">>  %s, ..., %s %s  He:%.4lf Be:%.4lf Ratio: %.4lf Threshold: %.2lf \n", alt_word, tword[2], tword[3], alt_he_score, alt_be_score, this_file_he_be_ratio, threshold); 
                    }

                alt_convince_ratio = convince_ratio = 0.0;
                if (have_alt) {
                    if (he_score > 0.0 || be_score > 0.0)
                        convince_ratio = (he_score > be_score) ? he_score / be_score : be_score / he_score;
                    if (alt_he_score > 0.0 || alt_be_score > 0.0)
                        alt_convince_ratio = (alt_he_score > alt_be_score) ? alt_he_score / alt_be_score : alt_be_score / alt_he_score;
                    if (alt_convince_ratio > convince_ratio) {
                        be_score = alt_be_score;
                        he_score = alt_he_score;
                        }
                    else
                        have_alt = 0;  // set it off for test below
                    }

                be_score_adjusted = be_score * this_file_he_be_ratio;

                if (pswit[PARANOID_SWITCH] && be_score == 0.0 && he_score == 0.0) {   // if paranoid, report all cases where the scores are zero
                    if (!pswit[ECHO_SWITCH])
                        printf("%s\n", aline);
                    printf("    Line %ld column %d - Query phrase \"%s %s %s\" \n\n", linecnt, (int)(s - aline) +1,
                        tword[1], tword[2], tword[3]);
                    }
                be_score_adjusted *= 2.0;
                if ((!strcmp(tword[2], "he")) && (be_score_adjusted > he_score * threshold)) {
                    if (!pswit[ECHO_SWITCH])
                        printf("%s\n", aline);
                    if (have_alt)
                        printf("    Line %ld column %d - Query phrase \"%s, ..., %s %s\" \n\n", linecnt, (int)(s - aline) +1,
                            alt_word, tword[2], tword[3]);
                    else
                        printf("    Line %ld column %d - Query phrase \"%s %s %s\" \n\n", linecnt, (int)(s - aline) +1,
                            tword[1], tword[2], tword[3]);
                    }
                if ((!strcmp(tword[2], "be")) && (he_score > be_score_adjusted * threshold)) {
                    if (!pswit[ECHO_SWITCH])
                        printf("%s\n", aline);
                    if (have_alt)
                        printf("    Line %ld column %d - Query phrase \"%s, ..., %s %s\" \n\n", linecnt, (int)(s - aline) +1,
                            alt_word, tword[2], tword[3]);
                    else
                        printf("    Line %ld column %d - Query phrase \"%s %s %s\" \n\n", linecnt, (int)(s - aline) +1,
                            tword[1], tword[2], tword[3]);
                    }
                }
            }

        }
    fclose (infile);
}


double binary_search(char *find_this, char *which_array[HE_POINTERS], long array_size)
{
    long hi, lo, weareat, wewereat;
    char target[MAX_ENTRY_LEN], compare_array[MAX_ENTRY_LEN];
    char *s;

    strncpy(target, find_this, sizeof(target));
    for (s = target; *s; s++) {
        if (*s == '|') *s = 1;
        if (*s == 9) *s = 0;
        }
    hi = array_size; lo = 0; wewereat = weareat = 0;

binsch:
    wewereat = weareat;    
    weareat = (hi + lo) / 2;
    if (wewereat == weareat) return(0.0); // Not found
    strncpy(compare_array, which_array[weareat], sizeof(compare_array));
    for (s = compare_array; *s; s++) {
        if (*s == '|') *s = 1;
        if (*s == 9) *s = 0;
        }
    switch (strcmp(target, compare_array)) {
        case 1:
            lo = weareat;
            break;
        case -1:
            hi = weareat;
            break;
        case 0:  // YAY!
            return(atof(which_array[weareat] + strlen(target)));
            break;
        }
    goto binsch;            
            

}
    
/* flgets - get one line from the input stream, checking for   */
/* the existence of exactly one CR/LF line-end per line.       */
/* Returns a pointer to the line.                              */

char *flgets(char *theline, int maxlen, FILE *thefile, long lcnt)
{
    char c;
    int len, isCR, cint;

    *theline = 0;
    len = isCR = 0;
    c = cint = fgetc(thefile);
    do {
        if (cint == EOF)
            return (NULL);
        if (c == 10)  /* either way, it's end of line */
            if (isCR)
                break;
            else {   /* Error - a LF without a preceding CR */
                break;
                }
        if (c == 13) {
            if (isCR) { /* Error - two successive CRs */
                }
            isCR = 1;
            }
        else {
             theline[len] = c;
             len++;
             theline[len] = 0;
             isCR = 0;
             }
        c = cint = fgetc(thefile);
    } while(len < maxlen);
    return(theline);
}





/* getaword - extracts the first/next "word" from the line, and puts */
/* it into "thisword". A word is defined as one English word unit    */
/* or at least that's what I'm trying for.                           */
/* Returns a pointer to the position in the line where we will start */
/* looking for the next word.                                        */

char *getaword(char *fromline, char *thisword)
{
    int i, wordlen;
    char *s;


    wordlen = 0;
    for ( ; !gcisdigit(*fromline) && !gcisalpha(*fromline) && *fromline ; fromline++ );

    /* V .20                                                                   */
    /* add a look-ahead to handle exceptions for numbers like 1,000 and 1.35.  */
    /* Especially yucky is the case of L1,000                                  */
    /* I hate this, and I see other ways, but I don't see that any is _better_.*/
    /* This section looks for a pattern of characters including a digit        */
    /* followed by a comma or period followed by one or more digits.           */
    /* If found, it returns this whole pattern as a word; otherwise we discard */
    /* the results and resume our normal programming.                          */
    s = fromline;
    for (  ; (gcisdigit(*s) || gcisalpha(*s) || *s == ',' || *s == '.') && wordlen < MAXWORDLEN ; s++ ) {
        thisword[wordlen] = *s;
        wordlen++;
        }
    thisword[wordlen] = 0;
    for (i = 1; i < wordlen -1; i++) {
        if (thisword[i] == '.' || thisword[i] == ',') {
            if (gcisdigit(thisword[i-1]) && gcisdigit(thisword[i-1])) {   /* we have one of the damned things */
                fromline = s;
                return(fromline);
                }
            }
        }

    /* we didn't find a punctuated number - do the regular getword thing */
    wordlen = 0;
    for (  ; (gcisdigit(*fromline) || gcisalpha(*fromline) || *fromline == '\'') && wordlen < MAXWORDLEN ; fromline++ ) {
        thisword[wordlen] = *fromline;
        wordlen++;
        }
    thisword[wordlen] = 0;
    return(fromline);
}


/* getaword - extracts the first/next "word" from the line, and puts */
/* it into "thisword". A word is defined as one English word unit    */
/* or at least that's what I'm trying for.                           */
/* Returns a pointer to the position in the line where we will start */
/* looking for the next word.                                        */

char *getawordwithpunct(char *fromline, char *thisword)
{
    int i, wordlen;
    char *s;


    wordlen = 0;
    for ( ; !gcisdigit(*fromline) && !gcisalpha(*fromline) && *fromline ; fromline++ );

    /* V .20                                                                   */
    /* add a look-ahead to handle exceptions for numbers like 1,000 and 1.35.  */
    /* Especially yucky is the case of L1,000                                  */
    /* I hate this, and I see other ways, but I don't see that any is _better_.*/
    /* This section looks for a pattern of characters including a digit        */
    /* followed by a comma or period followed by one or more digits.           */
    /* If found, it returns this whole pattern as a word; otherwise we discard */
    /* the results and resume our normal programming.                          */
    s = fromline;
    for (  ; (gcisdigit(*s) || gcisalpha(*s) || *s == ',' || *s == '.') && wordlen < MAXWORDLEN ; s++ ) {
        thisword[wordlen] = *s;
        wordlen++;
        }
    thisword[wordlen] = 0;
    for (i = 1; i < wordlen -1; i++) {
        if (thisword[i] == '.' || thisword[i] == ',') {
            if (gcisdigit(thisword[i-1]) && gcisdigit(thisword[i-1])) {   /* we have one of the damned things */
                fromline = s;
                return(fromline);
                }
            }
        }

    /* we didn't find a punctuated number - do the regular getword thing */
    /* but this time, preserve punctuation at end of word.               */
    wordlen = 0;
    for (  ; (gcisdigit(*fromline) || gcisalpha(*fromline) || ispunct(*fromline) || *fromline == '\'') && wordlen < MAXWORDLEN ; fromline++ ) {
        thisword[wordlen] = *fromline;
        wordlen++;
        }
    thisword[wordlen] = 0;
    return(fromline);
}





/* matchword - just a case-insensitive string matcher    */
/* yes, I know this is not efficient. I'll worry about   */
/* that when I have a clear idea where I'm going with it.*/

int matchword(char *checkfor, char *thisword)
{
    unsigned int ismatch, i;

    if (strlen(checkfor) != strlen(thisword)) return(0);

    ismatch = 1;     /* assume a match until we find a difference */
    for (i = 0; i <strlen(checkfor); i++)
        if (toupper(checkfor[i]) != toupper(thisword[i]))
            ismatch = 0;
    return (ismatch);
}





/* lowerit - lowercase the line. Yes, strlwr does the same job,  */
/* but not on all platforms, and I'm a bit paranoid about what   */
/* some implementations of tolower might do to hi-bit characters,*/
/* which shouldn't matter, but better safe than sorry.           */

void lowerit(char *theline)
{
    for ( ; *theline; theline++)
        if (*theline >='A' && *theline <='Z')
            *theline += 32;
}




/* gcisalpha is a special version that is somewhat lenient on 8-bit texts.     */
/* If we use the standard isalpha() function, 8-bit accented characters break  */
/* words, so that tete with accented characters appears to be two words, "t"   */
/* and "t", with 8-bit characters between them. This causes over-reporting of  */
/* errors. gcisalpha() recognizes accented letters from the CP1252 (Windows)   */
/* and ISO-8859-1 character sets, which are the most common PG 8-bit types.    */

int gcisalpha(unsigned char c)
{
    if (c >='a' && c <='z') return(1);
    if (c >='A' && c <='Z') return(1);
    if (c < 140) return(0);
    if (c >=192 && c != 208 && c != 215 && c != 222 && c != 240 && c != 247 && c != 254) return(1);
    if (c == 140 || c == 142 || c == 156 || c == 158 || c == 159) return (1);
    return(0);
}

/* gcisdigit is a special version that doesn't get confused in 8-bit texts.    */
int gcisdigit(unsigned char c)
{   
    if (c >= '0' && c <='9') return(1);
    return(0);
}

/* gcispunct returns 1 if punctuation, else zero    */
int gcispunct(unsigned char c)
{   
    if (strchr(".?!,;:", c)) return(1);
    return(0);
}



/* gcstrchr wraps strchr to return NULL if the character being searched for is zero */

char *gcstrchr(char *s, char c)
{
    if (c == 0) return(NULL);
    return(strchr(s,c));
}

void proghelp()                  /* explain program usage here */
{
    fputs ("V. 0.15-alpha-20051116. Copyright 2000-2005 Jim Tinsley <jtinsley@pobox.com>.\n",stderr);
    fputs ("This is *** ALPHA *** software: do NOT rely on it -- check all results!\n\n", stderr);
    fputs ("Jeebies comes wih ABSOLUTELY NO WARRANTY. For details, read the file COPYING.\n", stderr);
    fputs ("This is Free Software; you may redistribute it under certain conditions (GPL);\n", stderr);
    fputs ("read the file COPYING for details.\n\n", stderr);
    fputs ("jeebies checks for \"he/be\" errors in a PG English-language text.\n", stderr);
    fputs ("Usage is: jeebies [-p] [-t] [-e] filename\n", stderr);
    fputs ("          where -p = Paranoid  (many likely false positives).\n", stderr);
    fputs ("                -t = Tolerant (fewer likely false positives).\n", stderr);
    fputs ("                -e = does not Echo the text lines queried.\n", stderr);
}


/**********************************************************************/
/* Revision notes                                                     */
/* 2005-11-05                                                         */
/* 0.12 Sort-of "released" it, with hooks for GuiGuts                 */
/* 2005-11-15                                                         */
/* 0.15 Made binary search out of sheer embarrassment! :-)            */
/*      Fixed bug I seem to have introduced while making a            */
/*      "harmless" change to 0.12. Ugh.                               */
/*      Made "paranoid" report all he/be instances not in table.      */
/*      Memo to self: to make a jeebies data file on Win32 quickly    */
/*      1. Run wordcomb with "he" and "be" to get he.tri be.tri       */
/*      2. type he.tri |tr [A-Z] [a-z] | sort | nodups -c > he.jee    */
/*      having checked that the sort sequence puts "|" low.           */
/*      If nodups not available, you can do the same thing with       */
/*      uniq and sed.                                                 */
/*                                                                    */
/*                                                                    */
/**********************************************************************/

