/*************************************************************************/
/* gutcheck - check for assorted weirdnesses in a PG candidate text file */
/*                                                                       */
/* Version 0.99                                                          */
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
/* Overview comments:                                                    */
/*                                                                       */
/* If you're reading this, you're either interested in how to detect     */
/* formatting errors, or very very bored.                                */
/*                                                                       */
/* Gutcheck is a homebrew formatting checker specifically for            */
/* spotting common formatting problems in a PG e-text. I typically       */
/* run it once or twice on a file I'm about to submit; it usually        */
/* finds a few formatting problems. It also usually finds lots of        */
/* queries that aren't problems at all; it _really_ doesn't like         */
/* the standard PG header, for example.  It's optimized for straight     */
/* prose; poetry and non-fiction involving tables tend to trigger        */
/* false alarms.                                                         */
/*                                                                       */
/* The code of gutcheck is not very interesting, but the experience      */
/* of what constitutes a possible error may be, and the best way to      */
/* illustrate that is by example.                                        */
/*                                                                       */
/*                                                                       */
/* Here are some common typos found in PG texts that gutcheck            */
/* will flag as errors:                                                  */
/*                                                                       */
/* "Look!John , over there!"                                             */
/* <this is a HTML tag>                                                  */
/* &so is this;                                                          */
/* Margaret said: " Now you should start for school."                    */
/* Margaret said: "Now you should start for school. (if end of para)     */
/* The horse is said to he worth a lot.                                  */
/* 0K - this'11 make you look close1y.                                   */
/* "If you do. you'll regret it!"                                        */
/*                                                                       */
/* There are some complications . The extra space left around that       */
/* period was an error . . . but that ellipsis wasn't.                   */
/*                                                                       */
/* The last line of a paragraph                                          */
/* is usually short.                                                     */
/*                                                                       */
/* This period is an error.But the periods in a.m. aren't.               */
/*                                                                       */
/* Checks that are do-able but not (well) implemented are:               */
/*        Single-quote chcking.                                          */
/*          Despite 3 attempts at it, singlequote checking is still      */
/*          crap in gutcheck. It may not be possible without analysis    */
/*          of the whole paragraph.                                      */
/*                                                                       */
/*************************************************************************/


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define MAXWORDLEN    80    /* max length of one word             */
#define LINEBUFSIZE 2048    /* buffer size for an input line      */

#define MAX_USER_TYPOS 1000
#define USERTYPO_FILE "gutcheck.typ"

#ifndef MAX_PATH
#define MAX_PATH 16384
#endif

char aline[LINEBUFSIZE];
char prevline[LINEBUFSIZE];

                 /* Common typos. */
char *typo[] = { "teh", "th", "og", "fi", "ro", "adn", "yuo", "ot", "fo", "thet", "ane", "nad",
                "te", "ig", "acn",  "ahve", "alot", "anbd", "andt", "awya", "aywa", "bakc", "om",
                "btu", "byt", "cna", "cxan", "coudl", "dont", "didnt", "couldnt", "wouldnt", "doesnt", "shouldnt", "doign", "ehr",
                "hmi", "hse", "esle", "eyt", "fitrs", "firts", "foudn", "frmo", "fromt", "fwe", "gaurd", "gerat", "goign",
                "gruop", "haev", "hda", "hearign", "seeign", "sayign", "herat", "hge", "hsa", "hsi", "hte", "htere",
                "htese", "htey", "htis", "hvae", "hwich", "idae", "ihs", "iits", "int", "iwll", "iwth", "jsut", "loev",
                "sefl", "myu", "nkow", "nver", "nwe", "nwo", "ocur", "ohter", "omre", "onyl", "otehr", "otu", "owrk",
                "owuld", "peice", "peices", "peolpe", "peopel", "perhasp", "perhpas", "pleasent", "poeple", "porblem",
                "porblems", "rwite", "saidt", "saidh", "saids", "seh", "smae", "smoe", "sohw", "stnad", "stopry",
                "stoyr", "stpo", "tahn", "taht", "tath", "tehy", "tghe", "tghis", "theri", "theyll", "thgat", "thge",
                "thier", "thna", "thne", "thnig", "thnigs", "thsi", "thsoe", "thta", "timne", "tirne", "tkae",
                "tthe", "tyhat", "tyhe", "veyr", "vou", "vour", "vrey", "waht", "wasnt", "awtn", "watn", "wehn", "whic", "whcih",
                "whihc", "whta", "wihch", "wief", "wiht", "witha", "wiull", "wnat", "wnated", "wnats",
                "woh", "wohle", "wokr", "woudl", "wriet", "wrod", "wroet", "wroking", "wtih", "wuould", "wya", "yera",
                "yeras", "yersa", "yoiu", "youve", "ytou", "yuor",
                /* added h/b words for version 12 - removed a few with "tbe" v.25 */
                "abead", "ahle", "ahout", "ahove", "altbough", "balf", "bardly", "bas", "bave", "baving", "bebind", 
                "beld", "belp", "belped", "ber", "bere", "bim", "bis", "bome", "bouse", "bowever", "buge", "dehates", 
                "deht", "han", "hecause", "hecome", "heen", "hefore", "hegan", "hegin", "heing", 
                "helieve", "henefit", "hetter", "hetween", "heyond", "hig", "higber", "huild", "huy", "hy", "jobn", "joh", 
                "meanwbile", "memher", "memhers", "numher", "numhers", 
                "perbaps", "prohlem", "puhlic", "witbout", 
                /* and a few more for .18 */
                "arn", "hin", "hirn", "wrok", "wroked", "amd", "aud", "prornise", "prornised", "modem", "bo",
                "heside", "chapteb", "chaptee", "se",
                 ""};

char *usertypo[MAX_USER_TYPOS];

                 /* Common abbreviations and other OK words not to query as typos. */
char *okword[] = {"mr", "mrs", "ms", "mss", "mssrs", "ft", "pm", "st", "dr", "hmm", "h'm", "hmmm", "rd", "sh", "br",
                  "pp", "hm", "cf", "jr", "sr", "vs", "lb", "lbs", "ltd", "pompeii","hawaii","hawaiian",
                  "hotbed", "heartbeat", "heartbeats", "outbid", "frostbite", "frostbitten",
                  ""};

                 /* Common abbreviations that cause otherwise unexplained periods. */
char *abbrev[] = {"cent", "cents", "viz", "vol", "vols", "vid", "ed", "al", "etc", "op", "cit",
                  "deg", "min", "chap", "oz", "mme", "mlle", "mssrs",
                  ""};
                 /* Two-Letter combinations that rarely if ever start words, */
                 /* but are common scannos or otherwise common letter        */
                 /* combinations.                                            */
char *nostart[] = { "hr", "hl", "cb", "sb", "tb", "wb", "tl",
                    "tn", "rn", "lt", "tj",
                    "" };

                 /* Two-Letter combinations that rarely if ever end words    */
                 /* but are common scannos or otherwise common letter        */
                 /* combinations                                             */
char *noend[]   = { "cb", "gb", "pb", "sb", "tb", 
                    "wh","fr","br","qu","tw","gl","fl","sw","gr","sl","cl",
                    "iy",
                    ""};

char *markup[]  = { "a", "b", "big", "blockquote", "body", "br", "center", 
                    "col", "div", "em", "font", "h1", "h2", "h3", "h4", 
                    "h5", "h6", "head", "hr", "html", "i", "img", "li", 
                    "meta", "ol", "p", "pre", "small", "span", "strong", 
                    "sub", "sup", "table", "td", "tfoot", "thead", "title", 
                    "tr", "tt", "u", "ul", 
                    ""};

char *DPmarkup[] = { "<sc>", "</sc>", "/*", "*/", "/#", "#/", "/$", "$/",
                    ""};

char *nocomma[]  = { "the", "it's", "their", "an", "mrs", "a", "our", "that's",
                     "its", "whose", "every", "i'll", "your", "my", "mr", "mrs",
                     "i'm", "dr", "during", "let", "toward", "among",
                     ""};


char *noperiod[] = { "every", "i'm", "during", "that's", "their", "your", "our", "my", "or", 
                     "and", "but", "as", "if", "the", "its", "it's", "until", "than", "whether", 
                     "i'll", "whose", "who", "because", "when", "let", "till", "very",
                     "an", "among", "those", "into", "whom", "having", "thence",
                     ""}; 


char vowels[] = "aeiou";

struct {
    char *htmlent;
    char *htmlnum;
    char *textent;
    } entities[] = { "&amp;",           "&#38;",        "&", 
                     "&lt;",            "&#60;",        "<",
                     "&gt;",            "&#62;",        ">",
                     "&deg;",           "&#176;",       " degrees",
                     "&pound;",         "&#163;",       "L",
                     "&quot;",          "&#34;",        "\"",   /* -- quotation mark = APL quote, */
                     "&OElig;",         "&#338;",       "OE",  /* -- latin capital ligature OE, */
                     "&oelig;",         "&#339;",       "oe",  /* -- latin small ligature oe, U+0153 ISOlat2 --> */
                     "&Scaron;",        "&#352;",       "S",  /* -- latin capital letter S with caron, */
                     "&scaron;",        "&#353;",       "s",  /* -- latin small letter s with caron, */
                     "&Yuml;",          "&#376;",       "Y",  /* -- latin capital letter Y with diaeresis, */
                     "&circ;",          "&#710;",       "",  /* -- modifier letter circumflex accent, */
                     "&tilde;",         "&#732;",       "~",  /* -- small tilde, U+02DC ISOdia --> */
                     "&ensp;",          "&#8194;",      " ", /* -- en space, U+2002 ISOpub --> */
                     "&emsp;",          "&#8195;",      " ", /* -- em space, U+2003 ISOpub --> */
                     "&thinsp;",        "&#8201;",      " ", /* -- thin space, U+2009 ISOpub --> */
                     "&ndash;",         "&#8211;",      "-", /* -- en dash, U+2013 ISOpub --> */
                     "&mdash;",         "&#8212;",      "--", /* -- em dash, U+2014 ISOpub --> */
                     "&lsquo;",         "&#8216;",      "'", /* -- left single quotation mark, */
                     "&rsquo;",         "&#8217;",      "'", /* -- right single quotation mark, */
                     "&sbquo;",         "&#8218;",      "'", /* -- single low-9 quotation mark, U+201A NEW --> */
                     "&ldquo;",         "&#8220;",      "\"", /* -- left double quotation mark, */
                     "&rdquo;",         "&#8221;",      "\"", /* -- right double quotation mark, */
                     "&bdquo;",         "&#8222;",      "\"", /* -- double low-9 quotation mark, U+201E NEW --> */
                     "&lsaquo;",        "&#8249;",      "\"", /* -- single left-pointing angle quotation mark, */
                     "&rsaquo;",        "&#8250;",      "\"", /* -- single right-pointing angle quotation mark, */
                     "&nbsp;",          "&#160;",       " ", /* -- no-break space = non-breaking space, */
                     "&iexcl;",         "&#161;",       "!", /* -- inverted exclamation mark, U+00A1 ISOnum --> */
                     "&cent;",          "&#162;",       "c", /* -- cent sign, U+00A2 ISOnum --> */
                     "&pound;",         "&#163;",       "L", /* -- pound sign, U+00A3 ISOnum --> */
                     "&curren;",        "&#164;",       "$", /* -- currency sign, U+00A4 ISOnum --> */
                     "&yen;",           "&#165;",       "Y", /* -- yen sign = yuan sign, U+00A5 ISOnum --> */
                     "&sect;",          "&#167;",       "--", /* -- section sign, U+00A7 ISOnum --> */
                     "&uml;",           "&#168;",       " ", /* -- diaeresis = spacing diaeresis, */
                     "&copy;",          "&#169;",       "(C) ", /* -- copyright sign, U+00A9 ISOnum --> */
                     "&ordf;",          "&#170;",       " ", /* -- feminine ordinal indicator, U+00AA ISOnum --> */
                     "&laquo;",         "&#171;",       "\"", /* -- left-pointing double angle quotation mark */
                     "&shy;",           "&#173;",       "-", /* -- soft hyphen = discretionary hyphen, */
                     "&reg;",           "&#174;",       "(R) ", /* -- registered sign = registered trade mark sign, */
                     "&macr;",          "&#175;",       " ", /* -- macron = spacing macron = overline */
                     "&deg;",           "&#176;",       " degrees", /* -- degree sign, U+00B0 ISOnum --> */
                     "&plusmn;",        "&#177;",       "+-", /* -- plus-minus sign = plus-or-minus sign, */
                     "&sup2;",          "&#178;",       "2", /* -- superscript two = superscript digit two */
                     "&sup3;",          "&#179;",       "3", /* -- superscript three = superscript digit three */
                     "&acute;",         "&#180;",       " ", /* -- acute accent = spacing acute, */
                     "&micro;",         "&#181;",       "m", /* -- micro sign, U+00B5 ISOnum --> */
                     "&para;",          "&#182;",       "--", /* -- pilcrow sign = paragraph sign, */
                     "&cedil;",         "&#184;",       " ", /* -- cedilla = spacing cedilla, U+00B8 ISOdia --> */
                     "&sup1;",          "&#185;",       "1", /* -- superscript one = superscript digit one, */
                     "&ordm;",          "&#186;",       " ", /* -- masculine ordinal indicator, */
                     "&raquo;",         "&#187;",       "\"", /* -- right-pointing double angle quotation mark */
                     "&frac14;",        "&#188;",       "1/4", /* -- vulgar fraction one quarter */
                     "&frac12;",        "&#189;",       "1/2", /* -- vulgar fraction one half */
                     "&frac34;",        "&#190;",       "3/4", /* -- vulgar fraction three quarters */
                     "&iquest;",        "&#191;",       "?", /* -- inverted question mark */
                     "&Agrave;",        "&#192;",       "A", /* -- latin capital letter A with grave */
                     "&Aacute;",        "&#193;",       "A", /* -- latin capital letter A with acute, */
                     "&Acirc;",         "&#194;",       "A", /* -- latin capital letter A with circumflex, */
                     "&Atilde;",        "&#195;",       "A", /* -- latin capital letter A with tilde, */
                     "&Auml;",          "&#196;",       "A", /* -- latin capital letter A with diaeresis, */
                     "&Aring;",         "&#197;",       "A", /* -- latin capital letter A with ring above */
                     "&AElig;",         "&#198;",       "AE", /* -- latin capital letter AE */
                     "&Ccedil;",        "&#199;",       "C", /* -- latin capital letter C with cedilla, */
                     "&Egrave;",        "&#200;",       "E", /* -- latin capital letter E with grave, */
                     "&Eacute;",        "&#201;",       "E", /* -- latin capital letter E with acute, */
                     "&Ecirc;",         "&#202;",       "E", /* -- latin capital letter E with circumflex, */
                     "&Euml;",          "&#203;",       "E", /* -- latin capital letter E with diaeresis, */
                     "&Igrave;",        "&#204;",       "I", /* -- latin capital letter I with grave, */
                     "&Iacute;",        "&#205;",       "I", /* -- latin capital letter I with acute, */
                     "&Icirc;",         "&#206;",       "I", /* -- latin capital letter I with circumflex, */
                     "&Iuml;",          "&#207;",       "I", /* -- latin capital letter I with diaeresis, */
                     "&ETH;",           "&#208;",       "E", /* -- latin capital letter ETH, U+00D0 ISOlat1 --> */
                     "&Ntilde;",        "&#209;",       "N", /* -- latin capital letter N with tilde, */
                     "&Ograve;",        "&#210;",       "O", /* -- latin capital letter O with grave, */
                     "&Oacute;",        "&#211;",       "O", /* -- latin capital letter O with acute, */
                     "&Ocirc;",         "&#212;",       "O", /* -- latin capital letter O with circumflex, */
                     "&Otilde;",        "&#213;",       "O", /* -- latin capital letter O with tilde, */
                     "&Ouml;",          "&#214;",       "O", /* -- latin capital letter O with diaeresis, */
                     "&times;",         "&#215;",       "*", /* -- multiplication sign, U+00D7 ISOnum --> */
                     "&Oslash;",        "&#216;",       "O", /* -- latin capital letter O with stroke */
                     "&Ugrave;",        "&#217;",       "U", /* -- latin capital letter U with grave, */
                     "&Uacute;",        "&#218;",       "U", /* -- latin capital letter U with acute, */
                     "&Ucirc;",         "&#219;",       "U", /* -- latin capital letter U with circumflex, */
                     "&Uuml;",          "&#220;",       "U", /* -- latin capital letter U with diaeresis, */
                     "&Yacute;",        "&#221;",       "Y", /* -- latin capital letter Y with acute, */
                     "&THORN;",         "&#222;",       "TH", /* -- latin capital letter THORN, */
                     "&szlig;",         "&#223;",       "sz", /* -- latin small letter sharp s = ess-zed, */
                     "&agrave;",        "&#224;",       "a", /* -- latin small letter a with grave */
                     "&aacute;",        "&#225;",       "a", /* -- latin small letter a with acute, */
                     "&acirc;",         "&#226;",       "a", /* -- latin small letter a with circumflex, */
                     "&atilde;",        "&#227;",       "a", /* -- latin small letter a with tilde, */
                     "&auml;",          "&#228;",       "a", /* -- latin small letter a with diaeresis, */
                     "&aring;",         "&#229;",       "a", /* -- latin small letter a with ring above */
                     "&aelig;",         "&#230;",       "ae", /* -- latin small letter ae */
                     "&ccedil;",        "&#231;",       "c", /* -- latin small letter c with cedilla, */
                     "&egrave;",        "&#232;",       "e", /* -- latin small letter e with grave, */
                     "&eacute;",        "&#233;",       "e", /* -- latin small letter e with acute, */
                     "&ecirc;",         "&#234;",       "e", /* -- latin small letter e with circumflex, */
                     "&euml;",          "&#235;",       "e", /* -- latin small letter e with diaeresis, */
                     "&igrave;",        "&#236;",       "i", /* -- latin small letter i with grave, */
                     "&iacute;",        "&#237;",       "i", /* -- latin small letter i with acute, */
                     "&icirc;",         "&#238;",       "i", /* -- latin small letter i with circumflex, */
                     "&iuml;",          "&#239;",       "i", /* -- latin small letter i with diaeresis, */
                     "&eth;",           "&#240;",       "eth", /* -- latin small letter eth, U+00F0 ISOlat1 --> */
                     "&ntilde;",        "&#241;",       "n", /* -- latin small letter n with tilde, */
                     "&ograve;",        "&#242;",       "o", /* -- latin small letter o with grave, */
                     "&oacute;",        "&#243;",       "o", /* -- latin small letter o with acute, */
                     "&ocirc;",         "&#244;",       "o", /* -- latin small letter o with circumflex, */
                     "&otilde;",        "&#245;",       "o", /* -- latin small letter o with tilde, */
                     "&ouml;",          "&#246;",       "o", /* -- latin small letter o with diaeresis, */
                     "&divide;",        "&#247;",       "/", /* -- division sign, U+00F7 ISOnum --> */
                     "&oslash;",        "&#248;",       "o", /* -- latin small letter o with stroke, */
                     "&ugrave;",        "&#249;",       "u", /* -- latin small letter u with grave, */
                     "&uacute;",        "&#250;",       "u", /* -- latin small letter u with acute, */
                     "&ucirc;",         "&#251;",       "u", /* -- latin small letter u with circumflex, */
                     "&uuml;",          "&#252;",       "u", /* -- latin small letter u with diaeresis, */
                     "&yacute;",        "&#253;",       "y", /* -- latin small letter y with acute, */
                     "&thorn;",         "&#254;",       "th", /* -- latin small letter thorn, */
                     "&yuml;",          "&#255;",       "y", /* -- latin small letter y with diaeresis, */
                      "", "" };
                    
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
#define CHAR_FORESLASH    47
#define CHAR_CARAT        94

#define CHAR_UNDERSCORE    '_'
#define CHAR_OPEN_CBRACK   '{'
#define CHAR_CLOSE_CBRACK  '}'
#define CHAR_OPEN_RBRACK   '('
#define CHAR_CLOSE_RBRACK  ')'
#define CHAR_OPEN_SBRACK   '['
#define CHAR_CLOSE_SBRACK  ']'





/* ---- longest and shortest normal PG line lengths ----*/
#define LONGEST_PG_LINE   75
#define WAY_TOO_LONG      80
#define SHORTEST_PG_LINE  55

#define SWITCHES "ESTPXLOYHWVMUD" /* switches:-                            */
                                  /*     D - ignore DP-specific markup     */
                                  /*     E - echo queried line             */
                                  /*     S - check single quotes           */
                                  /*     T - check common typos            */
                                  /*     P - require closure of quotes on  */
                                  /*         every paragraph               */
                                  /*     X - "Trust no one" :-) Paranoid!  */
                                  /*         Queries everything            */
                                  /*     L - line end checking defaults on */
                                  /*         -L turns it off               */
                                  /*     O - overview. Just shows counts.  */
                                  /*     Y - puts errors to stdout         */
                                  /*         instead of stderr             */
                                  /*     H - Echoes header fields          */
                                  /*     M - Ignore markup in < >          */
                                  /*     U - Use file of User-defined Typos*/
                                  /*     W - Defaults for use on Web upload*/
                                  /*     V - Verbose - list EVERYTHING!    */
#define SWITNO 14                 /* max number of switch parms            */
                                  /*        - used for defining array-size */
#define MINARGS   1               /* minimum no of args excl switches      */
#define MAXARGS   1               /* maximum no of args excl switches      */

int pswit[SWITNO];                /* program switches set by SWITCHES      */

#define ECHO_SWITCH      0
#define SQUOTE_SWITCH    1
#define TYPO_SWITCH      2
#define QPARA_SWITCH     3
#define PARANOID_SWITCH  4
#define LINE_END_SWITCH  5
#define OVERVIEW_SWITCH  6
#define STDOUT_SWITCH    7
#define HEADER_SWITCH    8
#define WEB_SWITCH       9
#define VERBOSE_SWITCH   10
#define MARKUP_SWITCH    11
#define USERTYPO_SWITCH  12
#define DP_SWITCH        13



long cnt_dquot;       /* for overview mode, count of doublequote queries */
long cnt_squot;       /* for overview mode, count of singlequote queries */
long cnt_brack;       /* for overview mode, count of brackets queries */
long cnt_bin;         /* for overview mode, count of non-ASCII queries */
long cnt_odd;         /* for overview mode, count of odd character queries */
long cnt_long;        /* for overview mode, count of long line errors */
long cnt_short;       /* for overview mode, count of short line queries */
long cnt_punct;       /* for overview mode, count of punctuation and spacing queries */
long cnt_dash;        /* for overview mode, count of dash-related queries */
long cnt_word;        /* for overview mode, count of word queries */
long cnt_html;        /* for overview mode, count of html queries */
long cnt_lineend;     /* for overview mode, count of line-end queries */
long cnt_spacend;     /* count of lines with space at end  V .21 */
long linecnt;         /* count of total lines in the file */
long checked_linecnt; /* count of lines actually gutchecked V .26 */

void proghelp(void);
void procfile(char *);

#define LOW_THRESHOLD    0
#define HIGH_THRESHOLD   1

#define START 0
#define END 1
#define PREV 0
#define NEXT 1
#define FIRST_OF_PAIR 0
#define SECOND_OF_PAIR 1

#define MAX_WORDPAIR 1000

char running_from[MAX_PATH];

int mixdigit(char *);
char *getaword(char *, char *);
int matchword(char *, char *);
char *flgets(char *, int, FILE *, long);
void lowerit(char *);
int gcisalpha(unsigned char);
int gcisdigit(unsigned char);
int gcisletter(unsigned char);
char *gcstrchr(char *s, char c);
void postprocess_for_HTML(char *);
char *linehasmarkup(char *);
char *losemarkup(char *);
int tagcomp(char *, char *);
char *loseentities(char *);
int isroman(char *);
int usertypo_count;
void postprocess_for_DP(char *);

char wrk[LINEBUFSIZE];

/* This is disgustingly lazy, predefining max words & lengths,   */
/* but now I'm out of 16-bit restrictions, what's a couple of K? */
#define MAX_QWORD           50
#define MAX_QWORD_LENGTH    40
char qword[MAX_QWORD][MAX_QWORD_LENGTH];
char qperiod[MAX_QWORD][MAX_QWORD_LENGTH];
signed int dupcnt[MAX_QWORD];




int main(int argc, char **argv)
{
    char *argsw, *s;
    int i, switno, invarg;
    char usertypo_file[MAX_PATH];
    FILE *usertypofile;


    if (strlen(argv[0]) < sizeof(running_from))
        strcpy(running_from, argv[0]);  /* save the path to the executable gutcheck */

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

    pswit[PARANOID_SWITCH] ^= 1;         /* Paranoid checking is turned OFF, not on, by its switch */

    if (pswit[PARANOID_SWITCH]) {                         /* if running in paranoid mode */
        pswit[TYPO_SWITCH] = pswit[TYPO_SWITCH] ^ 1;      /* force typo checks as well   */
        }                                                 /* v.20 removed s and p switches from paranoid mode */

    pswit[LINE_END_SWITCH] ^= 1;         /* Line-end checking is turned OFF, not on, by its switch */
    pswit[ECHO_SWITCH] ^= 1;             /* V.21 Echoing is turned OFF, not on, by its switch      */

    if (pswit[OVERVIEW_SWITCH])       /* just print summary; don't echo */
        pswit[ECHO_SWITCH] = 0;

    /* Web uploads - for the moment, this is really just a placeholder     */
    /* until we decide what processing we really want to do on web uploads */
    if (pswit[WEB_SWITCH]) {          /* specific override for web uploads */
        pswit[ECHO_SWITCH] =     1;
        pswit[SQUOTE_SWITCH] =   0;
        pswit[TYPO_SWITCH] =     1;
        pswit[QPARA_SWITCH] =    0;
        pswit[PARANOID_SWITCH] = 1;
        pswit[LINE_END_SWITCH] = 0;
        pswit[OVERVIEW_SWITCH] = 0;
        pswit[STDOUT_SWITCH] =   0;
        pswit[HEADER_SWITCH] =   1;
        pswit[VERBOSE_SWITCH] =  0;
        pswit[MARKUP_SWITCH] =   0;
        pswit[USERTYPO_SWITCH] = 0;
        pswit[DP_SWITCH] = 0;
        }


    if (argc < MINARGS || argc > MAXARGS) {  /* check number of args */
        proghelp();
        return(1);            /* exit */
        }


    /* read in the user-defined stealth scanno list */

    if (pswit[USERTYPO_SWITCH]) {                    /* ... we were told we had one! */
        if ((usertypofile = fopen(USERTYPO_FILE, "rb")) == NULL) {   /* not in cwd. try gutcheck directory. */
            strcpy(usertypo_file, running_from);
            strcat(usertypo_file, USERTYPO_FILE);
            if ((usertypofile = fopen(usertypo_file, "rb")) == NULL) {  /* we ain't got no user typo file! */
                printf("   --> I couldn't find gutcheck.typ -- proceeding without user typos.\n");
                }
            }

        usertypo_count = 0;
        if (usertypofile) {  /* we managed to open a User Typo File! */
            if (pswit[USERTYPO_SWITCH]) {
                while (flgets(aline, LINEBUFSIZE-1, usertypofile, (long)usertypo_count)) {
                    if (strlen(aline) > 1) {
                        if ((int)*aline > 33) {
                            s = malloc(strlen(aline)+1);
                            if (!s) {
                                fprintf(stderr, "gutcheck: cannot get enough memory for user typo file!!\n");
                                exit(1);
                                }
                            strcpy(s, aline);
                            usertypo[usertypo_count] = s;
                            usertypo_count++;
                            if (usertypo_count >= MAX_USER_TYPOS) {
                                printf("   --> Only %d user-defined typos allowed: ignoring the rest\n");
                                break;
                                }
                            }
                        }
                    }
                }
            fclose(usertypofile);
            }
        }




    fprintf(stderr, "gutcheck: Check and report on an e-text\n");

    cnt_dquot = cnt_squot = cnt_brack = cnt_bin = cnt_odd = cnt_long =
    cnt_short = cnt_punct = cnt_dash = cnt_word = cnt_html = cnt_lineend =
    cnt_spacend = 0;

    procfile(argv[0]);

    if (pswit[OVERVIEW_SWITCH]) {
                         printf("    Checked %ld lines of %ld (head+foot = %ld)\n\n",
                            checked_linecnt, linecnt, linecnt - checked_linecnt);
                         printf("    --------------- Queries found --------------\n");
        if (cnt_long)    printf("    Long lines:                             %5ld\n",cnt_long);
        if (cnt_short)   printf("    Short lines:                            %5ld\n",cnt_short);
        if (cnt_lineend) printf("    Line-end problems:                      %5ld\n",cnt_lineend);
        if (cnt_word)    printf("    Common typos:                           %5ld\n",cnt_word);
        if (cnt_dquot)   printf("    Unmatched quotes:                       %5ld\n",cnt_dquot);
        if (cnt_squot)   printf("    Unmatched SingleQuotes:                 %5ld\n",cnt_squot);
        if (cnt_brack)   printf("    Unmatched brackets:                     %5ld\n",cnt_brack);
        if (cnt_bin)     printf("    Non-ASCII characters:                   %5ld\n",cnt_bin);
        if (cnt_odd)     printf("    Proofing characters:                    %5ld\n",cnt_odd);
        if (cnt_punct)   printf("    Punctuation & spacing queries:          %5ld\n",cnt_punct);
        if (cnt_dash)    printf("    Non-standard dashes:                    %5ld\n",cnt_dash);
        if (cnt_html)    printf("    Possible HTML tags:                     %5ld\n",cnt_html);
        printf("\n");
        printf("    TOTAL QUERIES                           %5ld\n",
            cnt_dquot + cnt_squot + cnt_brack + cnt_bin + cnt_odd + cnt_long +
            cnt_short + cnt_punct + cnt_dash + cnt_word + cnt_html + cnt_lineend);
        }

    return(0);
}



/* procfile - process one file */

void procfile(char *filename)
{

    char *s, *t, *s1, laststart, *wordstart;
    char inword[MAXWORDLEN], testword[MAXWORDLEN];
    char parastart[81];     /* first line of current para */
    FILE *infile;
    long quot, squot, firstline, alphalen, totlen, binlen,
         shortline, longline, verylongline, spacedash, emdash,
         space_emdash, non_PG_space_emdash, PG_space_emdash,
         footerline, dotcomma, start_para_line, astline, fslashline,
         standalone_digit, hyphens, htmcount, endquote_count;
    long spline, nspline;
    signed int i, j, llen, isemptyline, isacro, isellipsis, istypo, alower,
         eNon_A, eTab, eTilde, eAst, eFSlash, eCarat;
    signed int warn_short, warn_long, warn_bin, warn_dash, warn_dotcomma,
         warn_ast, warn_fslash, warn_digit, warn_hyphen, warn_endquote;
    unsigned int lastlen, lastblen;
    signed int s_brack, c_brack, r_brack, c_unders;
    signed int open_single_quote, close_single_quote, guessquote, dquotepar, squotepar;
    signed int isnewpara, vowel, consonant;
    char dquote_err[80], squote_err[80], rbrack_err[80], sbrack_err[80], cbrack_err[80],
         unders_err[80];
    signed int qword_index, qperiod_index, isdup;
    signed int enddash;


    


    laststart = CHAR_SPACE;
    lastlen = lastblen = 0;
    *dquote_err = *squote_err = *rbrack_err = *cbrack_err = *sbrack_err =
        *unders_err = *prevline = 0;
    linecnt = firstline = alphalen = totlen = binlen =
        shortline = longline = spacedash = emdash = checked_linecnt =
        space_emdash = non_PG_space_emdash = PG_space_emdash =
        footerline = dotcomma = start_para_line = astline = fslashline = 
        standalone_digit = hyphens = htmcount = endquote_count = 0;
    quot = squot = s_brack = c_brack = r_brack = c_unders = 0;
    i = llen = isemptyline = isacro = isellipsis = istypo = 0;
    warn_short = warn_long = warn_bin = warn_dash = warn_dotcomma = 
        warn_ast = warn_fslash = warn_digit = warn_endquote = 0;
    isnewpara = vowel = consonant = enddash = 0;
    spline = nspline = 0;
    qword_index = qperiod_index = isdup = 0;
    *inword = *testword = 0;
    open_single_quote = close_single_quote = guessquote = dquotepar = squotepar = 0;


    for (j = 0; j < MAX_QWORD; j++) {
        dupcnt[j] = 0;
        for (i = 0; i < MAX_QWORD_LENGTH; i++)
            qword[i][j] = 0;
            qperiod[i][j] = 0;
            }


    if ((infile = fopen(filename, "rb")) == NULL) {
        if (pswit[STDOUT_SWITCH])
            fprintf(stdout, "gutcheck: cannot open %s\n", filename);
        else
            fprintf(stderr, "gutcheck: cannot open %s\n", filename);
        exit(1);
        }

    fprintf(stdout, "\n\nFile: %s\n\n", filename);
    firstline = shortline = longline = verylongline = 0;


    /*****************************************************/
    /*                                                   */
    /*  Run a first pass - verify that it's a valid PG   */
    /*  file, decide whether to report some things that  */
    /*  occur many times in the text like long or short  */
    /*  lines, non-standard dashes, and other good stuff */
    /*  I'll doubtless think of later.                   */
    /*                                                   */
    /*****************************************************/

    /*****************************************************/
    /* V.24  Sigh. Yet Another Header Change             */
    /*****************************************************/

    while (fgets(aline, LINEBUFSIZE-1, infile)) {
        while (aline[strlen(aline)-1] == 10 || aline[strlen(aline)-1] == 13 ) aline[strlen(aline)-1] = 0;
        linecnt++;
        if (strstr(aline, "*END") && strstr(aline, "SMALL PRINT") && (strstr(aline, "PUBLIC DOMAIN") || strstr(aline, "COPYRIGHT"))) {
            if (spline)
                printf("   --> Duplicate header?\n");
            spline = linecnt + 1;   /* first line of non-header text, that is */
            }
        if (!strncmp(aline, "*** START", 9) && strstr(aline, "PROJECT GUTENBERG")) {
            if (nspline)
                printf("   --> Duplicate header?\n");
            nspline = linecnt + 1;   /* first line of non-header text, that is */
            }
        if (spline || nspline) {
            lowerit(aline);
            if (strstr(aline, "end") && strstr(aline, "project gutenberg")) {
                if (strstr(aline, "end") < strstr(aline, "project gutenberg")) {
                    if (footerline) {
                        if (!nspline) /* it's an old-form header - we can detect duplicates */
                            printf("   --> Duplicate footer?\n");
                        else 
                            ;
                        }
                    else {
                        footerline = linecnt;
                        }
                    }
                }
            }
        if (spline) firstline = spline;
        if (nspline) firstline = nspline;  /* override with new */

        llen = strlen(aline);
        totlen += llen;
        for (i = 0; i < llen; i++) {
            if ((unsigned char)aline[i] > 127) binlen++;
            if (gcisalpha(aline[i])) alphalen++;
            if (i > 0)
                if (aline[i] == CHAR_DQUOTE && isalpha(aline[i-1]))
                    endquote_count++;
            }
        if (strlen(aline) > 2
            && lastlen > 2 && lastlen < SHORTEST_PG_LINE
            && lastblen > 2 && lastblen > SHORTEST_PG_LINE
            && laststart != CHAR_SPACE)
                shortline++;

        if (*aline) /* fixed line below for 0.96 */
            if ((unsigned char)aline[strlen(aline)-1] <= CHAR_SPACE) cnt_spacend++;

        if (strstr(aline, ".,")) dotcomma++;
        /* 0.98 only count ast lines for ignoring purposes where there is */
        /* locase text on the line */
        if (strstr(aline, "*")) {
            for (s = aline; *s; s++)
                if (*s >='a' && *s <= 'z')
                    break;
             if (*s) astline++;
             }
        if (strstr(aline, "/"))
            fslashline++;
        for (i = llen-1; i > 0 && (unsigned char)aline[i] <= CHAR_SPACE; i--);
        if (aline[i] == '-' && aline[i-1] != '-') hyphens++;

        if (llen > LONGEST_PG_LINE) longline++;
        if (llen > WAY_TOO_LONG) verylongline++;

        if (strstr(aline, "<") && strstr(aline, ">")) {
            i = (signed int) (strstr(aline, ">") - strstr(aline, "<") + 1);
            if (i > 0) 
                htmcount++;
            if (strstr(aline, "<i>")) htmcount +=4; /* bonus marks! */
            }

        /* Check for spaced em-dashes */
        if (strstr(aline,"--")) {
            emdash++;
            if (*(strstr(aline, "--")-1) == CHAR_SPACE ||
               (*(strstr(aline, "--")+2) == CHAR_SPACE))
                    space_emdash++;
            if (*(strstr(aline, "--")-1) == CHAR_SPACE &&
               (*(strstr(aline, "--")+2) == CHAR_SPACE))
                    non_PG_space_emdash++;             /* count of em-dashes with spaces both sides */
            if (*(strstr(aline, "--")-1) != CHAR_SPACE &&
               (*(strstr(aline, "--")+2) != CHAR_SPACE))
                    PG_space_emdash++;                 /* count of PG-type em-dashes with no spaces */
            }

        for (s = aline; *s;) {
            s = getaword(s, inword);
            if (!strcmp(inword, "0") || !strcmp(inword, "1")) 
                standalone_digit++;
            }

        /* Check for spaced dashes */
        if (strstr(aline," -"))
            if (*(strstr(aline, " -")+2) != '-')
                    spacedash++;
        lastblen = lastlen;
        lastlen = strlen(aline);
        laststart = aline[0];

        }
    fclose(infile);


    /* now, based on this quick view, make some snap decisions */
    if (cnt_spacend > 0) {
        printf("   --> %ld lines in this file have white space at end\n", cnt_spacend);
        }

    warn_dotcomma = 1;
    if (dotcomma > 5) {
        warn_dotcomma = 0;
        printf("   --> %ld lines in this file contain '.,'. Not reporting them.\n", dotcomma);
        }

    /* if more than 50 lines, or one-tenth, are short, don't bother reporting them */
    warn_short = 1;
    if (shortline > 50 || shortline * 10 > linecnt) {
        warn_short = 0;
        printf("   --> %ld lines in this file are short. Not reporting short lines.\n", shortline);
        }

    /* if more than 50 lines, or one-tenth, are long, don't bother reporting them */
    warn_long = 1;
    if (longline > 50 || longline * 10 > linecnt) {
        warn_long = 0;
        printf("   --> %ld lines in this file are long. Not reporting long lines.\n", longline);
        }

    /* if more than 10 lines contain asterisks, don't bother reporting them V.0.97 */
    warn_ast = 1;
    if (astline > 10 ) {
        warn_ast = 0;
        printf("   --> %ld lines in this file contain asterisks. Not reporting them.\n", astline);
        }

    /* if more than 10 lines contain forward slashes, don't bother reporting them V.0.99 */
    warn_fslash = 1;
    if (fslashline > 10 ) {
        warn_fslash = 0;
        printf("   --> %ld lines in this file contain forward slashes. Not reporting them.\n", fslashline);
        }

    /* if more than 20 lines contain unpunctuated endquotes, don't bother reporting them V.0.99 */
    warn_endquote = 1;
    if (endquote_count > 20 ) {
        warn_endquote = 0;
        printf("   --> %ld lines in this file contain unpunctuated endquotes. Not reporting them.\n", endquote_count);
        }

    /* if more than 15 lines contain standalone digits, don't bother reporting them V.0.97 */
    warn_digit = 1;
    if (standalone_digit > 10 ) {
        warn_digit = 0;
        printf("   --> %ld lines in this file contain standalone 0s and 1s. Not reporting them.\n", standalone_digit);
        }

    /* if more than 20 lines contain hyphens at end, don't bother reporting them V.0.98 */
    warn_hyphen = 1;
    if (hyphens > 20 ) {
        warn_hyphen = 0;
        printf("   --> %ld lines in this file have hyphens at end. Not reporting them.\n", hyphens);
        }

    if (htmcount > 20 && !pswit[MARKUP_SWITCH]) {
        printf("   --> Looks like this is HTML. Switching HTML mode ON.\n");
        pswit[MARKUP_SWITCH] = 1;
        }
        
    if (verylongline > 0) {
        printf("   --> %ld lines in this file are VERY long!\n", verylongline);
        }

    /* If there are more non-PG spaced dashes than PG em-dashes,    */
    /* assume it's deliberate                                       */
    /* Current PG guidelines say don't use them, but older texts do,*/
    /* and some people insist on them whatever the guidelines say.  */
    /* V.20 removed requirement that PG_space_emdash be greater than*/
    /* ten before turning off warnings about spaced dashes.         */
    warn_dash = 1;
    if (spacedash + non_PG_space_emdash > PG_space_emdash) {
        warn_dash = 0;
        printf("   --> There are %ld spaced dashes and em-dashes. Not reporting them.\n", spacedash + non_PG_space_emdash);
        }

    /* if more than a quarter of characters are hi-bit, bug out */
    warn_bin = 1;
    if (binlen * 4 > totlen) {
        printf("   --> This file does not appear to be ASCII. Terminating. Best of luck with it!\n");
        exit(1);
        }
    if (alphalen * 4 < totlen) {
        printf("   --> This file does not appear to be text. Terminating. Best of luck with it!\n");
        exit(1);
        }
    if ((binlen * 100 > totlen) || (binlen > 100)) {
        printf("   --> There are a lot of foreign letters here. Not reporting them.\n");
        warn_bin = 0;
        }
    if (firstline && footerline)
        printf("    The PG header and footer appear to be already on.\n");
    else {
        if (firstline)
            printf("    The PG header is on - no footer.\n");
        if (footerline)
            printf("    The PG footer is on - no header.\n");
        }
    printf("\n");

    /* V.22 George Davis asked for an override switch to force it to list everything */
    if (pswit[VERBOSE_SWITCH]) {
        warn_bin = 1;
        warn_short = 1;
        warn_dotcomma = 1;
        warn_long = 1;
        warn_dash = 1;
        warn_digit = 1;
        warn_ast = 1;
        warn_fslash = 1;
        warn_hyphen = 1;
        warn_endquote = 1;
        printf("   *** Verbose output is ON -- you asked for it! ***\n");
        }

    if ((infile = fopen(filename, "rb")) == NULL) {
        if (pswit[STDOUT_SWITCH])
            fprintf(stdout, "gutcheck: cannot open %s\n", filename);
        else
            fprintf(stderr, "gutcheck: cannot open %s\n", filename);
        exit(1);
        }

    if (footerline > 0 && firstline > 0 && footerline > firstline && footerline - firstline < 100) { /* ugh */
        printf("   --> I don't really know where this text starts. \n");
        printf("       There are no reference points.\n");
        printf("       I'm going to have to report the header and footer as well.\n");
        firstline=0;
        }
        


    /*****************************************************/
    /*                                                   */
    /* Here we go with the main pass. Hold onto yer hat! */
    /*                                                   */
    /*****************************************************/

    /* Re-init some variables we've dirtied */
    quot = squot = linecnt = 0;
    laststart = CHAR_SPACE;
    lastlen = lastblen = 0;

    while (flgets(aline, LINEBUFSIZE-1, infile, linecnt+1)) {
        linecnt++;
        if (linecnt == 1) isnewpara = 1;
        if (pswit[DP_SWITCH])
            if (!strncmp(aline, "-----File: ", 11))
                continue;    // skip DP page separators completely
        if (linecnt < firstline || (footerline > 0 && linecnt > footerline)) {
            if (pswit[HEADER_SWITCH]) {
                if (!strncmp(aline, "Title:", 6))
                    printf("    %s\n", aline);
                if (!strncmp (aline, "Author:", 7))
                    printf("    %s\n", aline);
                if (!strncmp(aline, "Release Date:", 13))
                    printf("    %s\n", aline);
                if (!strncmp(aline, "Edition:", 8))
                    printf("    %s\n\n", aline);
                }
            continue;                /* skip through the header */
            }
        checked_linecnt++;
        s = aline;
        isemptyline = 1;      /* assume the line is empty until proven otherwise */

        /* If we are in a state of unbalanced quotes, and this line    */
        /* doesn't begin with a quote, output the stored error message */
        /* If the -P switch was used, print the warning even if the    */
        /* new para starts with quotes                                 */
        /* Version .20 - if the new paragraph does start with a quote, */
        /* but is indented, I was giving a spurious error. Need to     */
        /* check the first _non-space_ character on the line rather    */
        /* than the first character when deciding whether the para     */
        /* starts with a quote. Using *t for this.                     */
        t = s;
        while (*t == ' ') t++;
        if (*dquote_err)
            if (*t != CHAR_DQUOTE || pswit[QPARA_SWITCH]) {
                if (!pswit[OVERVIEW_SWITCH]) {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", parastart);
                    printf(dquote_err);
                    }
                else
                    cnt_dquot++;
            }
        if (*squote_err) {
            if (*t != CHAR_SQUOTE && *t != CHAR_OPEN_SQUOTE || pswit[QPARA_SWITCH] || squot) {
                if (!pswit[OVERVIEW_SWITCH]) {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", parastart);
                    printf(squote_err);
                    }
                else
                    cnt_squot++;
                }
            squot = 0;
            }
        if (*rbrack_err) {
            if (!pswit[OVERVIEW_SWITCH]) {
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", parastart);
                printf(rbrack_err);
                }
            else
                cnt_brack++;
            }
        if (*sbrack_err) {
            if (!pswit[OVERVIEW_SWITCH]) {
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", parastart);
                printf(sbrack_err);
                }
            else
                cnt_brack++;
            }
        if (*cbrack_err) {
            if (!pswit[OVERVIEW_SWITCH]) {
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", parastart);
                printf(cbrack_err);
                }
            else
                cnt_brack++;
            }
        if (*unders_err) {
            if (!pswit[OVERVIEW_SWITCH]) {
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", parastart);
                printf(unders_err);
                }
            else
                cnt_brack++;
            }

        *dquote_err = *squote_err = *rbrack_err = *cbrack_err = 
            *sbrack_err = *unders_err = 0;


        /* look along the line, accumulate the count of quotes, and see */
        /* if this is an empty line - i.e. a line with nothing on it    */
        /* but spaces.                                                  */
        /* V .12 also if line has just spaces, * and/or - on it, don't  */
        /* count it, since empty lines with asterisks or dashes to      */
        /* separate sections are common.                                */
        /* V .15 new single-quote checking - has to be better than the  */
        /* previous version, but how much better? fingers crossed!      */
        /* V .20 add period to * and - as characters on a separator line*/
        s = aline;
        while (*s) {
            if (*s == CHAR_DQUOTE) quot++;
            if (*s == CHAR_SQUOTE || *s == CHAR_OPEN_SQUOTE)
                if (s == aline) { /* at start of line, it can only be an openquote */
                    if (strncmp(s+2, "tis", 3) && strncmp(s+2, "Tis", 3)) /* hardcode a very common exception! */
                        open_single_quote++;
                    }
                else
                    if (gcisalpha(*(s-1)) && gcisalpha(*(s+1)))
                        ; /* do nothing! - it's definitely an apostrophe, not a quote */
                    else        /* it's outside a word - let's check it out */
                        if (*s == CHAR_OPEN_SQUOTE || gcisalpha(*(s+1))) { /* it damwell better BE an openquote */
                            if (strncmp(s+1, "tis", 3) && strncmp(s+1, "Tis", 3)) /* hardcode a very common exception! */
                                open_single_quote++;
                            }
                        else { /* now - is it a closequote? */
                            guessquote = 0;   /* accumulate clues */
                            if (gcisalpha(*(s-1))) { /* it follows a letter - could be either */
                                guessquote += 1;
                                if (*(s-1) == 's') { /* looks like a plural apostrophe */
                                    guessquote -= 3;
                                    if (*(s+1) == CHAR_SPACE)  /* bonus marks! */
                                        guessquote -= 2;
                                    }
                                }
                            else /* it doesn't have a letter either side */
                                if (strchr(".?!,;:", *(s-1)) && (strchr(".?!,;: ", *(s+1))))
                                    guessquote += 8; /* looks like a closequote */
                                else
                                    guessquote += 1;
                            if (open_single_quote > close_single_quote)
                                guessquote += 1; /* give it the benefit of some doubt - if a squote is already open */
                            else
                                guessquote -= 1;
                            if (guessquote >= 0)
                                close_single_quote++;
                            }

            if (*s != CHAR_SPACE
                && *s != '-'
                && *s != '.'
                && *s != CHAR_ASTERISK
                && *s != 13
                && *s != 10) isemptyline = 0;  /* ignore lines like  *  *  *  as spacers */
            if (*s == CHAR_UNDERSCORE) c_unders++;
            if (*s == CHAR_OPEN_CBRACK) c_brack++;
            if (*s == CHAR_CLOSE_CBRACK) c_brack--;
            if (*s == CHAR_OPEN_RBRACK) r_brack++;
            if (*s == CHAR_CLOSE_RBRACK) r_brack--;
            if (*s == CHAR_OPEN_SBRACK) s_brack++;
            if (*s == CHAR_CLOSE_SBRACK) s_brack--;
            s++;
            }

        if (isnewpara && !isemptyline) {   /* This line is the start of a new paragraph */
            start_para_line = linecnt;
            strncpy(parastart, aline, 80); /* Capture its first line in case we want to report it later */
            parastart[79] = 0;
            dquotepar = squotepar = 0; /* restart the quote count 0.98 */
            s = aline;
            while (!gcisalpha(*s) && !gcisdigit(*s) && *s) s++;    /* V.97 fixed bug - overran line and gave false warning - rare */
            if (*s >= 'a' && *s <='z') { /* and its first letter is lowercase */
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                if (!pswit[OVERVIEW_SWITCH])
                    printf("    Line %ld column %d - Paragraph starts with lower-case\n", linecnt, (int)(s - aline) +1);
                else
                    cnt_punct++;
                }
            isnewpara = 0; /* Signal the end of new para processing */
            }

        /* Check for an em-dash broken at line end */
        if (enddash && *aline == '-') {
            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
            if (!pswit[OVERVIEW_SWITCH])
                printf("    Line %ld column 1 - Broken em-dash?\n", linecnt);
            else
                cnt_punct++;
            }
        enddash = 0;
        for (s = aline + strlen(aline) - 1; *s == ' ' && s > aline; s--);
        if (s >= aline && *s == '-')
            enddash = 1;
            

        /* Check for invalid or questionable characters in the line */
        /* Anything above 127 is invalid for plain ASCII,  and      */
        /* non-printable control characters should also be flagged. */
        /* Tabs should generally not be there.                      */
        if (warn_bin) {
            eNon_A = eTab = eTilde = eCarat = eFSlash = eAst = 0;  /* don't repeat multiple warnings on one line */
            for (s = aline; *s; s++) {
                if (!eNon_A && ((*s < CHAR_SPACE && *s != 9 && *s != '\n') || (unsigned char)*s > 127)) {
                    i = *s;                           /* annoying kludge for signed chars */
                    if (i < 0) i += 256;
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        if (i > 127 && i < 160)
                            printf("    Line %ld column %d - Non-ISO-8859 character %d\n", linecnt, (int) (s - aline) + 1, i);
                        else
                            printf("    Line %ld column %d - Non-ASCII character %d\n", linecnt, (int) (s - aline) + 1, i);
                    else
                        cnt_bin++;
                    eNon_A = 1;
                    }
                if (!eTab && *s == CHAR_TAB) {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Tab character?\n", linecnt, (int) (s - aline) + 1);
                    else
                        cnt_odd++;
                    eTab = 1;
                    }
                if (!eTilde && *s == CHAR_TILDE) {  /* often used by OCR software to indicate an unrecognizable character */
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Tilde character?\n", linecnt, (int) (s - aline) + 1);
                    else
                        cnt_odd++;
                    eTilde = 1;
                    }
                if (!eCarat && *s == CHAR_CARAT) {  
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Carat character?\n", linecnt, (int) (s - aline) + 1);
                    else
                        cnt_odd++;
                    eCarat = 1;
                    }
                if (!eFSlash && *s == CHAR_FORESLASH && warn_fslash) {  
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Forward slash?\n", linecnt, (int) (s - aline) + 1);
                    else
                        cnt_odd++;
                    eFSlash = 1;
                    }
                /* report asterisks only in paranoid mode, since they're often deliberate */
                if (!eAst && pswit[PARANOID_SWITCH] && warn_ast && !isemptyline && *s == CHAR_ASTERISK) {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Asterisk?\n", linecnt, (int) (s - aline) + 1);
                    else
                        cnt_odd++;
                    eAst = 1;
                    }
                }
            }

        /* Check for line too long */
        if (warn_long) {
            if (strlen(aline) > LONGEST_PG_LINE) {
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                if (!pswit[OVERVIEW_SWITCH])
                    printf("    Line %ld column %d - Long line %d\n", linecnt, strlen(aline), strlen(aline));
                else
                    cnt_long++;
                }
            }

        /* Check for line too short.                                     */
        /* This one is a bit trickier to implement: we don't want to     */
        /* flag the last line of a paragraph for being short, so we      */
        /* have to wait until we know that our current line is a         */
        /* "normal" line, then report the _previous_ line if it was too  */
        /* short. We also don't want to report indented lines like       */
        /* chapter heads or formatted quotations. We therefore keep      */
        /* lastlen as the length of the last line examined, and          */
        /* lastblen as the length of the last but one, and try to        */
        /* suppress unnecessary warnings by checking that both were of   */
        /* "normal" length. We keep the first character of the last      */
        /* line in laststart, and if it was a space, we assume that the  */
        /* formatting is deliberate. I can't figure out a way to         */
        /* distinguish something like a quoted verse left-aligned or     */
        /* the header or footer of a letter from a paragraph of short    */
        /* lines - maybe if I examined the whole paragraph, and if the   */
        /* para has less than, say, 8 lines and if all lines are short,  */
        /* then just assume it's OK? Need to look at some texts to see   */
        /* how often a formula like this would get the right result.     */
        /* V0.99 changed the tolerance for length to ignore from 2 to 1  */
        if (warn_short) {
            if (strlen(aline) > 1
                && lastlen > 1 && lastlen < SHORTEST_PG_LINE
                && lastblen > 1 && lastblen > SHORTEST_PG_LINE
                && laststart != CHAR_SPACE) {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", prevline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Short line %d?\n", linecnt-1, strlen(prevline), strlen(prevline));
                    else
                        cnt_short++;
                    }
            }
        lastblen = lastlen;
        lastlen = strlen(aline);
        laststart = aline[0];

        /* look for punctuation at start of line */
        if  (*aline && strchr(".?!,;:",  aline[0]))  {            /* if it's punctuation */
            if (strncmp(". . .", aline, 5)) {   /* exception for ellipsis: V.98 tightened up to except only a full ellipsis */
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                if (!pswit[OVERVIEW_SWITCH])
                    printf("    Line %ld column 1 - Begins with punctuation?\n", linecnt);
                else
                    cnt_punct++;
                }
            }

        /* Check for spaced em-dashes                            */
        /* V.20 must check _all_ occurrences of "--" on the line */
        /* hence the loop - even if the first double-dash is OK  */
        /* there may be another that's wrong later on.           */
        if (warn_dash) {
            s = aline;
            while (strstr(s,"--")) {
                if (*(strstr(s, "--")-1) == CHAR_SPACE ||
                   (*(strstr(s, "--")+2) == CHAR_SPACE)) {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Spaced em-dash?\n", linecnt, (int) (strstr(s,"--") - aline) + 1);
                    else
                        cnt_dash++;
                    }
                s = strstr(s,"--") + 2;
                }
            }

        /* Check for spaced dashes */
        if (warn_dash)
            if (strstr(aline," -")) {
                if (*(strstr(aline, " -")+2) != '-') {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Spaced dash?\n", linecnt, (int) (strstr(aline," -") - aline) + 1);
                    else
                        cnt_dash++;
                    }
                }
            else
                if (strstr(aline,"- ")) {
                    if (*(strstr(aline, "- ")-1) != '-') {
                        if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                        if (!pswit[OVERVIEW_SWITCH])
                            printf("    Line %ld column %d - Spaced dash?\n", linecnt, (int) (strstr(aline,"- ") - aline) + 1);
                        else
                            cnt_dash++;
                        }
                    }

        /* v 0.99                                                       */
        /* Check for unmarked paragraphs indicated by separate speakers */
        /* May well be false positive:                                  */
        /* "Bravo!" "Wonderful!" called the crowd.                      */
        /* but useful all the same.                                     */
        s = wrk;
        *s = 0;
        if (strstr(aline, "\" \"")) s = strstr(aline, "\" \"");
        if (strstr(aline, "\"  \"")) s = strstr(aline, "\"  \"");
        if (*s) {
            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
            if (!pswit[OVERVIEW_SWITCH])
                printf("    Line %ld column %d - Query missing paragraph break?\n", linecnt, (int)(s - aline) +1);
            else
                cnt_punct++;
            }



        /* Check for "to he" and other easy he/be errors          */
        /* This is a very inadequate effort on the he/be problem, */
        /* but the phrase "to he" is always an error, whereas "to */
        /* be" is quite common. I chuckle when it does catch one! */
        /* Similarly, '"Quiet!", be said.' is a non-be error      */
        /* V .18 - "to he" is _not_ always an error!:             */
        /*           "Where they went to he couldn't say."        */
        /* but I'm leaving it in anyway.                          */
        /* V .20 Another false positive:                          */
        /*       What would "Cinderella" be without the . . .     */
        /* and another "If he wants to he can see for himself."   */
        /* V .21 Added " is be " and " be is " and " be was "     */
        /* V .99 Added jeebies code -- removed again.             */
        /*       Is jeebies code worth adding? Rare to see he/be  */
        /*       errors with modern OCR. Separate program? Yes!   */
        /*       jeebies does the job without cluttering up this. */
        /*       We do get a few more queryable pairs from the    */
        /*       project though -- they're cheap to implement.    */
        /*       Also added a column number for guiguts.          */

        s = wrk;
        *s = 0;
        if (strstr(aline," to he ")) s = strstr(aline," to he ");
        if (strstr(aline,"\" be ")) s = strstr(aline,"\" be ");
        if (strstr(aline,"\", be ")) s = strstr(aline,"\", be ");
        if (strstr(aline," is be ")) s = strstr(aline," is be ");
        if (strstr(aline," be is ")) s = strstr(aline," be is ");
        if (strstr(aline," was be ")) s = strstr(aline," was be ");
        if (strstr(aline," be would ")) s = strstr(aline," be would ");
        if (strstr(aline," be could ")) s = strstr(aline," be could ");
        if (*s) {
            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
            if (!pswit[OVERVIEW_SWITCH])
                printf("    Line %ld column %d - Query he/be error?\n", linecnt, (int)(s - aline) +1);
            else
                cnt_word++;
            }

        s = wrk;
        *s = 0;
        if (strstr(aline," i bad ")) s = strstr(aline," i bad ");
        if (strstr(aline," you bad ")) s = strstr(aline," you bad ");
        if (strstr(aline," he bad ")) s = strstr(aline," he bad ");
        if (strstr(aline," she bad ")) s = strstr(aline," she bad ");
        if (strstr(aline," they bad ")) s = strstr(aline," they bad ");
        if (strstr(aline," a had ")) s = strstr(aline," a had ");
        if (strstr(aline," the had ")) s = strstr(aline," the had ");
        if (*s) {
            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
            if (!pswit[OVERVIEW_SWITCH])
                printf("    Line %ld column %d - Query had/bad error?\n", linecnt, (int)(s - aline) +1);
            else
                cnt_word++;
            }


        /* V .97 Added ", hut "  Not too common, hut pretty certain   */
        /* V.99 changed to add a column number for guiguts            */
        s = wrk;
        *s = 0;
        if (strstr(aline,", hut ")) s = strstr(aline,", hut ");
        if (strstr(aline,"; hut ")) s = strstr(aline,"; hut ");
        if (*s) {
            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
            if (!pswit[OVERVIEW_SWITCH])
                printf("    Line %ld column %d - Query hut/but error?\n", linecnt, (int)(s - aline) +1);
            else
                cnt_word++;
            }

        /* Special case - angled bracket in front of "From" placed there by an MTA */
        /* when sending an e-mail.  V .21                                          */
        if (strstr(aline, ">From")) {
            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
            if (!pswit[OVERVIEW_SWITCH])
                printf("    Line %ld column %d - Query angled bracket with From\n", linecnt, (int)(strstr(aline, ">From") - aline) +1);
            else
                cnt_punct++;
            }

        /* V 0.98 Check for a single character line - often an overflow from bad wrapping. */
        if (*aline && !*(aline+1)) {
            if (*aline == 'I' || *aline == 'V' || *aline == 'X' || *aline == 'L' || gcisdigit(*aline))
                ; /* nothing - ignore numerals alone on a line. */
            else {
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                if (!pswit[OVERVIEW_SWITCH])
                    printf("    Line %ld column 1 - Query single character line\n", linecnt);
                else
                    cnt_punct++;
                }
            }

        /* V 0.98 Check for I" - often should be ! */
        if (strstr(aline, " I\"")) {
            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
            if (!pswit[OVERVIEW_SWITCH])
                printf("    Line %ld column %ld - Query I=exclamation mark?\n", linecnt, strstr(aline, " I\"") - aline);
            else
                cnt_punct++;
            }

        /* V 0.98 Check for period without a capital letter. Cut-down from gutspell */
        /*        Only works when it happens on a single line.                      */

        if (pswit[PARANOID_SWITCH])
            for (t = s = aline; strstr(t,". ");) {
                t = strstr(t, ". ");
                if (t == s)  {
                    t++;
                    continue; /* start of line punctuation is handled elsewhere */
                    }
                if (!gcisalpha(*(t-1))) {
                    t++;
                    continue;
                    }
                s1 = t+2;
                while (*s1 && !gcisalpha(*s1) && !isdigit(*s1))
                    s1++;
                if (*s1 >= 'a' && *s1 <= 'z') {  /* we have something to investigate */
                    istypo = 1;
                    for (s1 = t - 1; s1 >= s && 
                        (gcisalpha(*s1) || gcisdigit(*s1) || 
                        (*s1 == CHAR_SQUOTE && gcisalpha(*(s1+1)) && gcisalpha(*(s1-1)))); s1--); /* so let's go back and find out */
                    s1++;
                    for (i = 0; *s1 && *s1 != '.'; s1++, i++)
                        testword[i] = *s1;
                    testword[i] = 0;
                    for (i = 0; *abbrev[i]; i++)
                        if (!strcmp(testword, abbrev[i]))
                            istypo = 0;
//                    if (*testword >= 'A' && *testword <= 'Z') 
//                        istypo = 0;
                    if (gcisdigit(*testword)) istypo = 0;
                    if (!*(testword+1)) istypo = 0;
                    if (isroman(testword)) istypo = 0;
                    if (istypo) {
                        istypo = 0;
                        for (i = 0; testword[i]; i++)
                            if (strchr(vowels, testword[i]))
                                istypo = 1;
                        }
                    if (istypo) {
                        isdup = 0;
                        if (strlen(testword) < MAX_QWORD_LENGTH && !pswit[VERBOSE_SWITCH])
                            for (i = 0; i < qperiod_index; i++)
                                if (!strcmp(testword, qperiod[i])) {
                                    isdup = 1;
                                    }
                        if (!isdup) {
                            if (qperiod_index < MAX_QWORD && strlen(testword) < MAX_QWORD_LENGTH) {
                                strcpy(qperiod[qperiod_index], testword);
                                qperiod_index++;
                                }
                            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                            if (!pswit[OVERVIEW_SWITCH])
                                printf("    Line %ld column %d - Extra period?\n", linecnt, (int)(t - aline)+1);
                            else
                                cnt_punct++;
                            }
                        }
                    }
                t++;
                }


        /* Check for words usually not followed by punctuation 0.99 */
        for (s = aline; *s;) {
            wordstart = s;
            s = getaword(s, inword);
            if (!*inword) continue;
            lowerit(inword);
            for (i = 0; *nocomma[i]; i++)
                if (!strcmp(inword, nocomma[i])) {
                    if (*s == ',' || *s == ';' || *s == ':') {
                        if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                        if (!pswit[OVERVIEW_SWITCH])
                            printf("    Line %ld column %d - Query punctuation after %s?\n", linecnt, (int)(s - aline)+1, inword);
                        else
                            cnt_punct++;
                        }
                    }
            for (i = 0; *noperiod[i]; i++)
                if (!strcmp(inword, noperiod[i])) {
                    if (*s == '.' || *s == '!') {
                        if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                        if (!pswit[OVERVIEW_SWITCH])
                            printf("    Line %ld column %d - Query punctuation after %s?\n", linecnt, (int)(s - aline)+1, inword);
                        else
                            cnt_punct++;
                        }
                    }
            }



        /* Check for commonly mistyped words, and digits like 0 for O in a word */
        for (s = aline; *s;) {
            wordstart = s;
            s = getaword(s, inword);
            if (!*inword) continue; /* don't bother with empty lines */
            if (mixdigit(inword)) {
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                if (!pswit[OVERVIEW_SWITCH])
                    printf("    Line %ld column %ld - Query digit in %s\n", linecnt, (int)(wordstart - aline) + 1, inword);
                else
                    cnt_word++;
                }

            /* put the word through a series of tests for likely typos and OCR errors */
            /* V.21 I had allowed lots of typo-checking even with the typo switch     */
            /* turned off, but I really should disallow reporting of them when        */
            /* the switch is off. Hence the "if" below.                               */
            if (pswit[TYPO_SWITCH]) {
                istypo = 0;
                strcpy(testword, inword);
                alower = 0;
                for (i = 0; i < (signed int)strlen(testword); i++) { /* lowercase for testing */
                    if (testword[i] >= 'a' && testword[i] <= 'z') alower = 1;
                    if (alower && testword[i] >= 'A' && testword[i] <= 'Z') {
                        /* we have an uppercase mid-word. However, there are common cases: */
                        /*   Mac and Mc like McGill                                        */
                        /*   French contractions like l'Abbe                               */
                        if ((i == 2 && testword[0] == 'm' && testword[1] == 'c') ||
                            (i == 3 && testword[0] == 'm' && testword[1] == 'a' && testword[2] == 'c') ||
                            (i > 0 && testword[i-1] == CHAR_SQUOTE))
                                ; /* do nothing! */

                        else {  /* V.97 - remove separate case of uppercase within word so that         */
                                /* names like VanAllen fall into qword_index and get reported only once */
                            istypo = 1;
                            }
                        }
                    testword[i] = (char)tolower(testword[i]);
                    }

                /* check for certain unlikely two-letter combinations at word start and end */
                /* V.0.97 - this replaces individual hardcoded checks in previous versions */
                if (strlen(testword) > 1) {
                    for (i = 0; *nostart[i]; i++)
                        if (!strncmp(testword, nostart[i], 2))
                            istypo = 1;
                    for (i = 0; *noend[i]; i++)
                        if (!strncmp(testword + strlen(testword) -2, noend[i], 2))
                            istypo = 1;
                    }


                /* ght is common, gbt never. Like that. */
                if (strstr(testword, "cb")) istypo = 1;
                if (strstr(testword, "gbt")) istypo = 1;
                if (strstr(testword, "pbt")) istypo = 1;
                if (strstr(testword, "tbs")) istypo = 1;
                if (strstr(testword, "mrn")) istypo = 1;
                if (strstr(testword, "ahle")) istypo = 1;
                if (strstr(testword, "ihle")) istypo = 1;

                /* "TBE" does happen - like HEARTBEAT - but uncommon.                    */
                /*  Also "TBI" - frostbite, outbid - but uncommon.                       */
                /*  Similarly "ii" like Hawaii, or Pompeii, and in Roman numerals,       */
                /*  but these are covered in V.20. "ii" is a common scanno.              */
                if (strstr(testword, "tbi")) istypo = 1;
                if (strstr(testword, "tbe")) istypo = 1;
                if (strstr(testword, "ii")) istypo = 1;

                /* check for no vowels or no consonants. */
                /* If none, flag a typo                  */
                if (!istypo && strlen(testword)>1) {
                    vowel = consonant = 0;
                    for (i = 0; testword[i]; i++)
                        if (testword[i] == 'y' || gcisdigit(testword[i])) {  /* Yah, this is loose. */
                            vowel++;
                            consonant++;
                            }
                        else
                            if  (strchr(vowels, testword[i])) vowel++;
                            else consonant++;
                    if (!vowel || !consonant) {
                        istypo = 1;
                        }
                    }

                /* now exclude the word from being reported if it's in */
                /* the okword list                                     */
                for (i = 0; *okword[i]; i++)
                    if (!strcmp(testword, okword[i]))
                        istypo = 0;

                /* what looks like a typo may be a Roman numeral. Exclude these */
                if (istypo)
                    if (isroman(testword))
                        istypo = 0;

                /* check the manual list of typos */
                if (!istypo)
                    for (i = 0; *typo[i]; i++)
                        if (!strcmp(testword, typo[i]))
                            istypo = 1;


                /* V.21 - check lowercase s and l - special cases */
                /* V.98 - added "i" and "m"                       */
                /* V.99 - added "j" often a semi-colon gone wrong */
                /*      - and "d" for a missing apostrophe - he d */
                /*      - and "n" for "in"                        */
                if (!istypo && strlen(testword) == 1)
                    if (strchr("slmijdn", *inword))
                        istypo = 1;


                if (istypo) {
                    isdup = 0;
                    if (strlen(testword) < MAX_QWORD_LENGTH && !pswit[VERBOSE_SWITCH])
                        for (i = 0; i < qword_index; i++)
                            if (!strcmp(testword, qword[i])) {
                                isdup = 1;
                                ++dupcnt[i];
                                }
                    if (!isdup) {
                        if (qword_index < MAX_QWORD && strlen(testword) < MAX_QWORD_LENGTH) {
                            strcpy(qword[qword_index], testword);
                            qword_index++;
                            }
                        if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                        if (!pswit[OVERVIEW_SWITCH]) {
                            printf("    Line %ld column %d - Query word %s", linecnt, (int)(wordstart - aline) + 1, inword);
                            if (strlen(testword) < MAX_QWORD_LENGTH && !pswit[VERBOSE_SWITCH])
                                printf(" - not reporting duplicates");
                            printf("\n");
                            }
                        else
                            cnt_word++;
                        }
                    }
                }        /* end of typo-checking */

                /* check the user's list of typos */
                if (!istypo)
                    if (usertypo_count)
                        for (i = 0; i < usertypo_count; i++)
                            if (!strcmp(testword, usertypo[i])) {
                                if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                                if (!pswit[OVERVIEW_SWITCH])  
                                    printf("    Line %ld column %d - Query possible scanno %s\n", linecnt, (int)(wordstart - aline) + 2, inword);
                                }



            if (pswit[PARANOID_SWITCH] && warn_digit) {   /* in paranoid mode, query all 0 and 1 standing alone - added warn_digit V.97*/
                if (!strcmp(inword, "0") || !strcmp(inword, "1")) {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Query standalone %s\n", linecnt, (int)(wordstart - aline) + 2, inword);
                    else
                        cnt_word++;
                    }
                }
            }

        /* look for added or missing spaces around punctuation and quotes */
        /* If there is a punctuation character like ! with no space on    */
        /* either side, suspect a missing!space. If there are spaces on   */
        /* both sides , assume a typo. If we see a double quote with no   */
        /* space or punctuation on either side of it, assume unspaced     */
        /* quotes "like"this.                                             */
        llen = strlen(aline);
        for (i = 1; i < llen; i++) {                               /* for each character in the line after the first */
            if  (strchr(".?!,;:_", aline[i])) {                    /* if it's punctuation */
                isacro = 0;                       /* we need to suppress warnings for acronyms like M.D. */
                isellipsis = 0;                   /* we need to suppress warnings for ellipsis . . . */
                if ( (gcisalpha(aline[i-1]) && gcisalpha(aline[i+1])) ||     /* if there are letters on both sides of it or ... */
                   (gcisalpha(aline[i+1]) && strchr("?!,;:", aline[i]))) { /* ...if it's strict punctuation followed by an alpha */
                    if (aline[i] == '.') {
                        if (i > 2)
                            if (aline[i-2] == '.') isacro = 1;
                        if (i + 2 < llen)
                            if (aline[i+2] == '.') isacro = 1;
                        }
                    if (!isacro) {
                        if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                        if (!pswit[OVERVIEW_SWITCH])
                            printf("    Line %ld column %d - Missing space?\n", linecnt, i+1);
                        else
                            cnt_punct++;
                        }
                    }
                if (aline[i-1] == CHAR_SPACE && (aline[i+1] == CHAR_SPACE || aline[i+1] == 0)) { /* if there are spaces on both sides, or space before and end of line */
                    if (aline[i] == '.') {
                        if (i > 2)
                            if (aline[i-2] == '.') isellipsis = 1;
                        if (i + 2 < llen)
                            if (aline[i+2] == '.') isellipsis = 1;
                        }
                    if (!isemptyline && !isellipsis) {
                        if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                        if (!pswit[OVERVIEW_SWITCH])
                            printf("    Line %ld column %d - Spaced punctuation?\n", linecnt, i+1);
                        else
                            cnt_punct++;
                        }
                    }
                }
            }

        /* 0.98 -- split out the characters that CANNOT be preceded by space */
        llen = strlen(aline);
        for (i = 1; i < llen; i++) {                             /* for each character in the line after the first */
            if  (strchr("?!,;:", aline[i])) {                    /* if it's punctuation that _cannot_ have a space before it */
                if (aline[i-1] == CHAR_SPACE && !isemptyline && aline[i+1] != CHAR_SPACE) { /* if aline[i+1) DOES == space, it was already reported just above */
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Spaced punctuation?\n", linecnt, i+1);
                    else
                        cnt_punct++;
                    }
                }
            }


        /* 0.99 -- special case " .X" where X is any alpha. */
        /* This plugs a hole in the acronym code above. Inelegant, but maintainable. */
        llen = strlen(aline);
        for (i = 1; i < llen; i++) {             /* for each character in the line after the first */
            if  (aline[i] == '.') {              /* if it's a period */
                if (aline[i-1] == CHAR_SPACE && gcisalpha(aline[i+1])) { /* if the period follows a space and is followed by a letter */
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Spaced punctuation?\n", linecnt, i+1);
                    else
                        cnt_punct++;
                    }
                }
            }




        /* v.21 breaking out the search for unspaced doublequotes        */
        /* This is not as efficient, but it's more maintainable          */
        /* V.97 added underscore to the list of characters not to query, */
        /* since underscores are commonly used as italics indicators.    */
        /* V.98 Added slash as well, same reason.                        */
        for (i = 1; i < llen; i++) {                               /* for each character in the line after the first */
            if (aline[i] == CHAR_DQUOTE) {
                if ((!strchr(" _-.'`,;:!/([{?}])",  aline[i-1]) &&
                     !strchr(" _-.'`,;:!/([{?}])",  aline[i+1]) &&
                     aline[i+1] != 0
                     || (!strchr(" _-([{'`", aline[i-1]) && gcisalpha(aline[i+1])))) {
                        if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                        if (!pswit[OVERVIEW_SWITCH])
                            printf("    Line %ld column %d - Unspaced quotes?\n", linecnt, i+1);
                        else
                            cnt_punct++;
                        }
                }
            }


        /* v.98 check parity of quotes                             */
        /* v.99 added !*(s+1) in some tests to catch "I am," he said, but I will not be soon". */
        for (s = aline; *s; s++) {
            if (*s == CHAR_DQUOTE) {
                if (!(dquotepar = !dquotepar)) {    /* parity even */
                    if (!strchr("_-.'`/,;:!?)]} ",  *(s+1))) {
                        if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                        if (!pswit[OVERVIEW_SWITCH])
                            printf("    Line %ld column %d - Wrongspaced quotes?\n", linecnt, (int)(s - aline)+1);
                        else
                            cnt_punct++;
                        }
                    }
                else {                              /* parity odd */
                    if (!gcisalpha(*(s+1)) && !isdigit(*(s+1)) && !strchr("_-/.'`([{$",  *(s+1)) || !*(s+1)) {
                        if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                        if (!pswit[OVERVIEW_SWITCH])
                            printf("    Line %ld column %d - Wrongspaced quotes?\n", linecnt, (int)(s - aline)+1);
                        else
                            cnt_punct++;
                        }
                    }
                }
            }

            if (*aline == CHAR_DQUOTE) {
                if (strchr(",;:!?)]} ", aline[1])) {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column 1 - Wrongspaced quotes?\n", linecnt, (int)(s - aline)+1);
                    else
                        cnt_punct++;
                    }
                }

        if (pswit[SQUOTE_SWITCH])
            for (s = aline; *s; s++) {
                if ((*s == CHAR_SQUOTE || *s == CHAR_OPEN_SQUOTE)
                     && ( s == aline || (s > aline && !gcisalpha(*(s-1))) || !gcisalpha(*(s+1)))) {
                    if (!(squotepar = !squotepar)) {    /* parity even */
                        if (!strchr("_-.'`/\",;:!?)]} ",  *(s+1))) {
                            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                            if (!pswit[OVERVIEW_SWITCH])
                                printf("    Line %ld column %d - Wrongspaced singlequotes?\n", linecnt, (int)(s - aline)+1);
                            else
                                cnt_punct++;
                            }
                        }
                    else {                              /* parity odd */
                        if (!gcisalpha(*(s+1)) && !isdigit(*(s+1)) && !strchr("_-/\".'`",  *(s+1)) || !*(s+1)) {
                            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                            if (!pswit[OVERVIEW_SWITCH])
                                printf("    Line %ld column %d - Wrongspaced singlequotes?\n", linecnt, (int)(s - aline)+1);
                            else
                                cnt_punct++;
                            }
                        }
                    }
                }
                    

        /* v.20 also look for double punctuation like ,. or ,,     */
        /* Thanks to DW for the suggestion!                        */
        /* I'm putting this in a separate loop for clarity         */
        /* In books with references, ".," and ".;" are common      */
        /* e.g. "etc., etc.," and vol. 1.; vol 3.;                 */
        /* OTOH, from my initial tests, there are also fairly      */
        /* common errors. What to do? Make these cases paranoid?   */
        /* V.21 ".," is the most common, so invented warn_dotcomma */
        /* to suppress detailed reporting if it occurs often       */
        llen = strlen(aline);
        for (i = 0; i < llen; i++)                  /* for each character in the line */
            if (strchr(".?!,;:", aline[i])          /* if it's punctuation */
            && (strchr(".?!,;:", aline[i+1]))
            && aline[i] && aline[i+1])      /* followed by punctuation, it's a query, unless . . . */
                if (
                (aline[i] == aline[i+1]
                && (aline[i] == '.' || aline[i] == '?' || aline[i] == '!'))
                || (!warn_dotcomma && aline[i] == '.' && aline[i+1] == ',')
                )
                        ; /* do nothing for .. !! and ?? which can be legit */
                else {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Double punctuation?\n", linecnt, i+1);
                    else
                        cnt_punct++;
                    }

        /* v.21 breaking out the search for spaced doublequotes */
        /* This is not as efficient, but it's more maintainable */
        s = aline;
        while (strstr(s," \" ")) {
            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
            if (!pswit[OVERVIEW_SWITCH])
                printf("    Line %ld column %d - Spaced doublequote?\n", linecnt, (int)(strstr(s," \" ")-aline+1));
            else
                cnt_punct++;
            s = strstr(s," \" ") + 2;
            }

        /* v.20 also look for spaced singlequotes ' and `  */
        s = aline;
        while (strstr(s," ' ")) {
            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
            if (!pswit[OVERVIEW_SWITCH])
                printf("    Line %ld column %d - Spaced singlequote?\n", linecnt, (int)(strstr(s," ' ")-aline+1));
            else
                cnt_punct++;
            s = strstr(s," ' ") + 2;
            }

        s = aline;
        while (strstr(s," ` ")) {
            if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
            if (!pswit[OVERVIEW_SWITCH])
                printf("    Line %ld column %d - Spaced singlequote?\n", linecnt, (int)(strstr(s," ` ")-aline+1));
            else
                cnt_punct++;
            s = strstr(s," ` ") + 2;
            }

        /* v.99 check special case of 'S instead of 's at end of word */
        s = aline + 1;
        while (*s) {
            if (*s == CHAR_SQUOTE && *(s+1) == 'S' && *(s-1)>='a' && *(s-1)<='z')  {
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                if (!pswit[OVERVIEW_SWITCH])
                    printf("    Line %ld column %d - Capital \"S\"?\n", linecnt, (int)(s-aline+2));
                else
                    cnt_punct++;
                }
            s++;
            }


        /* v.21 Now check special cases - start and end of line - */
        /* for single and double quotes. Start is sometimes [sic] */
        /* but better to query it anyway.                         */
        /* While I'm here, check for dash at end of line          */
        llen = strlen(aline);
        if (llen > 1) {
            if (aline[llen-1] == CHAR_DQUOTE ||
                aline[llen-1] == CHAR_SQUOTE ||
                aline[llen-1] == CHAR_OPEN_SQUOTE)
                if (aline[llen-2] == CHAR_SPACE) {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Spaced quote?\n", linecnt, llen);
                    else
                        cnt_punct++;
                    }
            
            /* V 0.98 removed aline[0] == CHAR_DQUOTE from the test below, since */
            /* Wrongspaced quotes test also catches it for "                     */
            if (aline[0] == CHAR_SQUOTE ||
                aline[0] == CHAR_OPEN_SQUOTE)
                if (aline[1] == CHAR_SPACE) {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column 1 - Spaced quote?\n", linecnt);
                    else
                        cnt_punct++;
                    }
            /* dash at end of line may well be legit - paranoid mode only */
            /* and don't report em-dash at line-end                       */
            if (pswit[PARANOID_SWITCH] && warn_hyphen) {
                for (i = llen-1; i > 0 && (unsigned char)aline[i] <= CHAR_SPACE; i--);
                if (aline[i] == '-' && aline[i-1] != '-') {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld column %d - Hyphen at end of line?\n", linecnt, i);
                    }
                }
            }

        /* v.21 also look for brackets surrounded by alpha                    */
        /* Brackets are often unspaced, but shouldn't be surrounded by alpha. */
        /* If so, suspect a scanno like "a]most"                              */
        llen = strlen(aline);
        for (i = 1; i < llen-1; i++) {           /* for each character in the line except 1st & last*/
            if (strchr("{[()]}", aline[i])         /* if it's a bracket */
                && gcisalpha(aline[i-1]) && gcisalpha(aline[i+1])) {
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                if (!pswit[OVERVIEW_SWITCH])
                    printf("    Line %ld column %d - Unspaced bracket?\n", linecnt, i);
                else
                    cnt_punct++;
                }
            }
        /* The "Cinderella" case, back in again! :-S Give it another shot */
        if (warn_endquote) {
            llen = strlen(aline);
            for (i = 1; i < llen; i++) {           /* for each character in the line except 1st */
                if (aline[i] == CHAR_DQUOTE)
                    if (isalpha(aline[i-1])) {
                        if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                        if (!pswit[OVERVIEW_SWITCH])
                            printf("    Line %ld column %d - endquote missing punctuation?\n", linecnt, i);
                        else
                            cnt_punct++;
                        }
                }
            }

        llen = strlen(aline);

        /* Check for <HTML TAG> */
        /* If there is a < in the line, followed at some point  */
        /* by a > then we suspect HTML                          */
        if (strstr(aline, "<") && strstr(aline, ">")) {
            i = (signed int) (strstr(aline, ">") - strstr(aline, "<") + 1);
            if (i > 0) {
                strncpy(wrk, strstr(aline, "<"), i);
                wrk[i] = 0;
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                if (!pswit[OVERVIEW_SWITCH])
                    printf("    Line %ld column %d - HTML Tag? %s \n", linecnt, (int)(strstr(aline, "<") - aline) + 1, wrk);
                else
                    cnt_html++;
                }
            }

        /* Check for &symbol; HTML                   */
        /* If there is a & in the line, followed at  */
        /* some point by a ; then we suspect HTML    */
        if (strstr(aline, "&") && strstr(aline, ";")) {
            i = (int)(strstr(aline, ";") - strstr(aline, "&") + 1);
            for (s = strstr(aline, "&"); s < strstr(aline, ";"); s++)   
                if (*s == CHAR_SPACE) i = 0;                /* 0.99 don't report "Jones & Son;" */
            if (i > 0) {
                strncpy(wrk, strstr(aline,"&"), i);
                wrk[i] = 0;
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", aline);
                if (!pswit[OVERVIEW_SWITCH])
                    printf("    Line %ld column %d - HTML symbol? %s \n", linecnt, (int)(strstr(aline, "&") - aline) + 1, wrk);
                else
                    cnt_html++;
                }
            }

        /* At end of paragraph, check for mismatched quotes.           */
        /* We don't want to report an error immediately, since it is a */
        /* common convention to omit the quotes at end of paragraph if */
        /* the next paragraph is a continuation of the same speaker.   */
        /* Where this is the case, the next para should begin with a   */
        /* quote, so we store the warning message and only display it  */
        /* at the top of the next iteration if the new para doesn't    */
        /* start with a quote.                                         */
        /* The -p switch overrides this default, and warns of unclosed */
        /* quotes on _every_ paragraph, whether the next begins with a */
        /* quote or not.                                               */
        /* Version .16 - only report mismatched single quotes if       */
        /* an open_single_quotes was found.                            */

        if (isemptyline) {          /* end of para - add up the totals */
            if (quot % 2)
                sprintf(dquote_err, "    Line %ld - Mismatched quotes\n", linecnt);
            if (pswit[SQUOTE_SWITCH] && open_single_quote && (open_single_quote != close_single_quote) )
                sprintf(squote_err,"    Line %ld - Mismatched singlequotes?\n", linecnt);
            if (pswit[SQUOTE_SWITCH] && open_single_quote
                                     && (open_single_quote != close_single_quote)
                                     && (open_single_quote != close_single_quote +1) )
                squot = 1;    /* flag it to be noted regardless of the first char of the next para */
            if (r_brack)
                sprintf(rbrack_err, "    Line %ld - Mismatched round brackets?\n", linecnt);
            if (s_brack)
                sprintf(sbrack_err, "    Line %ld - Mismatched square brackets?\n", linecnt);
            if (c_brack)
                sprintf(cbrack_err, "    Line %ld - Mismatched curly brackets?\n", linecnt);
            if (c_unders % 2)
                sprintf(unders_err, "    Line %ld - Mismatched underscores?\n", linecnt);
            quot = s_brack = c_brack = r_brack = c_unders =
                open_single_quote = close_single_quote = 0;
            isnewpara = 1;     /* let the next iteration know that it's starting a new para */
            }

        /* V.21 _ALSO_ at end of paragraph, check for omitted punctuation. */
        /*      by working back through prevline. DW.                      */
        /* Hmmm. Need to check this only for "normal" paras.               */
        /* So what is a "normal" para? ouch!                               */
        /* Not normal if one-liner (chapter headings, etc.)                */
        /* Not normal if doesn't contain at least one locase letter        */
        /* Not normal if starts with space                                 */

        /* 0.99 tighten up on para end checks. Disallow comma and */
        /* semi-colon. Check for legit para end before quotes.    */
        if (isemptyline) {          /* end of para */
            for (s = prevline, i = 0; *s && !i; s++)
                if (gcisletter(*s))
                    i = 1;    /* use i to indicate the presence of a letter on the line */
            /* This next "if" is a problem.
            /* If I say "start_para_line <= linecnt - 1", that includes one-line
            /* "paragraphs" like chapter heads. Lotsa false positives.
            /* If I say "start_para_line < linecnt - 1" it doesn't, but then it
            /* misses genuine one-line paragraphs.
            /* So what do I do? */
            if (i
                && lastblen > 2
                && start_para_line < linecnt - 1
                && *prevline > CHAR_SPACE
                ) {
                for (i = strlen(prevline)-1; (prevline[i] == CHAR_DQUOTE || prevline[i] == CHAR_SQUOTE) && prevline[i] > CHAR_SPACE && i > 0; i--);
                for (  ; i > 0; i--) {
                    if (gcisalpha(prevline[i])) {
                        if (pswit[ECHO_SWITCH]) printf("\n%s\n", prevline);
                        if (!pswit[OVERVIEW_SWITCH])
                            printf("    Line %ld column %d - No punctuation at para end?\n", linecnt-1, strlen(prevline));
                        else
                            cnt_punct++;
                        break;
                        }
                    if (strchr("-.:!([{?}])", prevline[i]))
                        break;
                    }
                }
            }
        strcpy(prevline, aline);
    }
    fclose (infile);
    if (!pswit[OVERVIEW_SWITCH])
        for (i = 0; i < MAX_QWORD; i++)
            if (dupcnt[i])
                printf("\nNote: Queried word %s was duplicated %d time%s\n", qword[i], dupcnt[i], "s");
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
                if (pswit[LINE_END_SWITCH]) {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", theline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld - No CR?\n", lcnt);
                    else
                        cnt_lineend++;
                    }
                break;
                }
        if (c == 13) {
            if (isCR) { /* Error - two successive CRs */
                if (pswit[LINE_END_SWITCH]) {
                    if (pswit[ECHO_SWITCH]) printf("\n%s\n", theline);
                    if (!pswit[OVERVIEW_SWITCH])
                        printf("    Line %ld - Two successive CRs?\n", lcnt);
                    else
                        cnt_lineend++;
                    }
                }
            isCR = 1;
            }
        else {
            if (pswit[LINE_END_SWITCH] && isCR) {
                if (pswit[ECHO_SWITCH]) printf("\n%s\n", theline);
                if (!pswit[OVERVIEW_SWITCH])
                    printf("    Line %ld column %d - CR without LF?\n", lcnt, len+1);
                else
                    cnt_lineend++;
                }
             theline[len] = c;
             len++;
             theline[len] = 0;
             isCR = 0;
             }
        c = cint = fgetc(thefile);
    } while(len < maxlen);
    if (pswit[MARKUP_SWITCH])  
        postprocess_for_HTML(theline);
    if (pswit[DP_SWITCH])  
        postprocess_for_DP(theline);
    return(theline);
}




/* mixdigit - takes a "word" as a parameter, and checks whether it   */
/* contains a mixture of alpha and digits. Generally, this is an     */
/* error, but may not be for cases like 4th or L5 12s. 3d.           */
/* Returns 0 if no error found, 1 if error.                          */

int mixdigit(char *checkword)   /* check for digits like 1 or 0 in words */
{
    int wehaveadigit, wehavealetter, firstdigits, query, wl;
    char *s;


    wehaveadigit = wehavealetter = query = 0;
    for (s = checkword; *s; s++)
        if (gcisalpha(*s))
            wehavealetter = 1;
        else
            if (gcisdigit(*s))
                wehaveadigit = 1;
    if (wehaveadigit && wehavealetter) {         /* Now exclude common legit cases, like "21st" and "12l. 3s. 11d." */
        query = 1;
        wl = strlen(checkword);
        for (firstdigits = 0; gcisdigit(checkword[firstdigits]); firstdigits++)
            ;
        /* digits, ending in st, rd, nd, th of either case */
        /* 0.99 donovan points out an error below. Turns out */
        /*      I was using matchword like strcmp when the   */
        /*      return values are different! Duh.            */
        if (firstdigits + 2 == wl &&
              (matchword(checkword + wl - 2, "st")
            || matchword(checkword + wl - 2, "rd")
            || matchword(checkword + wl - 2, "nd")
            || matchword(checkword + wl - 2, "th"))
            )
                query = 0;
        if (firstdigits + 3 == wl &&
              (matchword(checkword + wl - 3, "sts")
            || matchword(checkword + wl - 3, "rds")
            || matchword(checkword + wl - 3, "nds")
            || matchword(checkword + wl - 3, "ths"))
            )
                query = 0;
        if (firstdigits + 3 == wl &&
              (matchword(checkword + wl - 4, "stly")
            || matchword(checkword + wl - 4, "rdly")
            || matchword(checkword + wl - 4, "ndly")
            || matchword(checkword + wl - 4, "thly"))
            )
                query = 0;

        /* digits, ending in l, L, s or d */
        if (firstdigits + 1 == wl &&
            (checkword[wl-1] == 'l'
            || checkword[wl-1] == 'L'
            || checkword[wl-1] == 's'
            || checkword[wl-1] == 'd'))
                query = 0;
        /* L at the start of a number, representing Britsh pounds, like L500  */
        /* This is cute. We know the current word is mixeddigit. If the first */
        /* letter is L, there must be at least one digit following. If both   */
        /* digits and letters follow, we have a genuine error, else we have a */
        /* capital L followed by digits, and we accept that as a non-error.   */
        if (checkword[0] == 'L')
            if (!mixdigit(checkword+1))
                query = 0;
        }
    return (query);
}




/* getaword - extracts the first/next "word" from the line, and puts */
/* it into "thisword". A word is defined as one English word unit    */
/* -- or at least that's what I'm trying for.                        */
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


/* Is this word a Roman Numeral?                                    */
/* v 0.99 improved to be better. It still doesn't actually          */
/* validate that the number is a valid Roman Numeral -- for example */
/* it will pass MXXXXXXXXXX as a valid Roman Numeral, but that's not*/
/* what we're here to do. If it passes this, it LOOKS like a Roman  */
/* numeral. Anyway, the actual Romans were pretty tolerant of bad   */
/* arithmetic, or expressions thereof, except when it came to taxes.*/
/* Allow any number of M, an optional D, an optional CM or CD,      */
/* any number of optional Cs, an optional XL or an optional XC, an  */
/* optional IX or IV, an optional V and any number of optional Is.  */
/* Good enough for jazz chords.                                     */

int isroman(char *t)
{
    char *s;

    if (!t || !*t) return (0);

    s = t;

    while (*t == 'm' && *t ) t++;
    if (*t == 'd') t++;
    if (*t == 'c' && *(t+1) == 'm') t+=2;
    if (*t == 'c' && *(t+1) == 'd') t+=2;
    while (*t == 'c' && *t) t++;
    if (*t == 'x' && *(t+1) == 'l') t+=2;
    if (*t == 'x' && *(t+1) == 'c') t+=2;
    if (*t == 'l') t++;
    while (*t == 'x' && *t) t++;
    if (*t == 'i' && *(t+1) == 'x') t+=2;
    if (*t == 'i' && *(t+1) == 'v') t+=2;
    if (*t == 'v') t++;
    while (*t == 'i' && *t) t++;
    if (!*t) return (1);

    return(0);
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

/* gcisletter is a special version that doesn't get confused in 8-bit texts.    */
/* Yeah, we're ISO-8891-1-specific. So sue me.                                  */
int gcisletter(unsigned char c)
{   
    if ((c >= 'A' && c <='Z') || (c >= 'a' && c <='z') || c >= 192) return(1);
    return(0);
}




/* gcstrchr wraps strchr to return NULL if the character being searched for is zero */

char *gcstrchr(char *s, char c)
{
    if (c == 0) return(NULL);
    return(strchr(s,c));
}

/* postprocess_for_DP is derived from postprocess_for_HTML          */
/* It is invoked with the -d switch from flgets().                  */
/* It simply "removes" from the line a hard-coded set of common     */
/* DP-specific tags, so that the line passed to the main routine has*/
/* been pre-cleaned of DP markup.                                   */

void postprocess_for_DP(char *theline)
{

    char *s, *t;
    int i;

    if (!*theline) 
        return;

    for (i = 0; *DPmarkup[i]; i++) {
        s = strstr(theline, DPmarkup[i]);
        while (s) {
            t = s + strlen(DPmarkup[i]);
            while (*t) {
                *s = *t;
                t++; s++;
                }
            *s = 0;
            s = strstr(theline, DPmarkup[i]);
            }
        }

}


/* postprocess_for_HTML is, at the moment (0.97), a very nasty      */
/* short-term fix for Charlz. Nasty, nasty, nasty.                  */
/* It is invoked with the -m switch from flgets().                  */
/* It simply "removes" from the line a hard-coded set of common     */
/* HTML tags and "replaces" a hard-coded set of common HTML         */
/* entities, so that the line passed to the main routine has        */
/* been pre-cleaned of HTML. This is _so_ not the right way to      */
/* deal with HTML, but what Charlz needs now is not HTML handling   */
/* proper: just ignoring <i> tags and some others.                  */
/* To be revisited in future releases!                              */

void postprocess_for_HTML(char *theline)
{

    if (strstr(theline, "<") && strstr(theline, ">"))
        while (losemarkup(theline))
            ;
    while (loseentities(theline))
        ;
}

char *losemarkup(char *theline)
{
    char *s, *t;
    int i;

    if (!*theline) 
        return(NULL);

    s = strstr(theline, "<");
    t = strstr(theline, ">");
    if (!s || !t) return(NULL);
    for (i = 0; *markup[i]; i++)
        if (!tagcomp(s+1, markup[i])) {
            if (!*(t+1)) {
                *s = 0;
                return(s);
                }
            else
                if (t > s) {
                    strcpy(s, t+1);
                    return(s);
                    }
        }
    /* it's an unrecognized <xxx> */
    return(NULL);
}

char *loseentities(char *theline)
{
    int i;
    char *s, *t;

    if (!*theline) 
        return(NULL);

    for (i = 0; *entities[i].htmlent; i++) {
        s = strstr(theline, entities[i].htmlent);
        if (s) {
            t = malloc((size_t)strlen(s));
            if (!t) return(NULL);
            strcpy(t, s + strlen(entities[i].htmlent));
            strcpy(s, entities[i].textent);
            strcat(s, t);
            free(t);
            return(theline);
            }
        }

    /* V0.97 Duh. Forgot to check the htmlnum member */
    for (i = 0; *entities[i].htmlnum; i++) {
        s = strstr(theline, entities[i].htmlnum);
        if (s) {
            t = malloc((size_t)strlen(s));
            if (!t) return(NULL);
            strcpy(t, s + strlen(entities[i].htmlnum));
            strcpy(s, entities[i].textent);
            strcat(s, t);
            free(t);
            return(theline);
            }
        }
    return(NULL);
}


int tagcomp(char *strin, char *basetag)
{
    char *s, *t;

    s = basetag;
    t  = strin;
    if (*t == '/') t++; /* ignore a slash */
    while (*s && *t) {
        if (tolower(*s) != tolower(*t)) return(1);
        s++; t++;
        }
    /* OK, we have < followed by a valid tag start  */
    /* should I do something about length?          */
    /* this is messy. The length of an <i> tag is   */
    /* limited, but a <table> could go on for miles */
    /* so I'd have to parse the tags . . . ugh.     */
    /* It isn't what Charlz needs now, so mark it   */
    /* as 'pending'.                                */
    return(0);
}

void proghelp()                  /* explain program usage here */
{
    fputs("V. 0.99. Copyright 2000-2005 Jim Tinsley <jtinsley@pobox.com>.\n",stderr);
    fputs("Gutcheck comes wih ABSOLUTELY NO WARRANTY. For details, read the file COPYING.\n", stderr);
    fputs("This is Free Software; you may redistribute it under certain conditions (GPL);\n", stderr);
    fputs("read the file COPYING for details.\n\n", stderr);
    fputs("Usage is: gutcheck [-setpxloyhud] filename\n",stderr);
    fputs("  where -s checks single quotes, -e suppresses echoing lines, -t checks typos\n",stderr);
    fputs("  -x (paranoid) switches OFF -t and extra checks, -l turns OFF line-end checks\n",stderr);
    fputs("  -o just displays overview without detail, -h echoes header fields\n",stderr);
    fputs("  -v (verbose) unsuppresses duplicate reporting, -m suppresses markup\n",stderr);
    fputs("  -d ignores DP-specific markup,\n",stderr);
    fputs("  -u uses a file gutcheck.typ to query user-defined possible typos\n",stderr);
    fputs("Sample usage: gutcheck warpeace.txt \n",stderr);
    fputs("\n",stderr);
    fputs("Gutcheck looks for errors in Project Gutenberg(TM) etexts.\n", stderr);
    fputs("Gutcheck queries anything it thinks shouldn't be in a PG text; non-ASCII\n",stderr);
    fputs("characters like accented letters, lines longer than 75 or shorter than 55,\n",stderr);
    fputs("unbalanced quotes or brackets, a variety of badly formatted punctuation, \n",stderr);
    fputs("HTML tags, some likely typos. It is NOT a substitute for human judgement.\n",stderr);
    fputs("\n",stderr);
}



/*********************************************************************
  Revision History:

  04/22/01 Cleaned up some stuff and released .10

           ---------------

  05/09/01 Added the typo list, added two extra cases of he/be error,
           added -p switch, OPEN_SINGLE QUOTE char as .11

           ---------------

  05/20/01 Increased the typo list,
           added paranoid mode,
           ANSIfied the code and added some casts
              so the compiler wouldn't keep asking if I knew what I was doing,
           fixed bug in l.s.d. condition (thanks, Dave!),
           standardized spacing when echoing,
           added letter-combo checking code to typo section,
           added more h/b words to typo array.
           Not too sure about putting letter combos outside of the TYPO conditions -
           someone is sure to have a book about the tbaka tribe, or something. Anyway, let's see.
           Released as .12

           ---------------

  06/01/01 Removed duplicate reporting of Tildes, asterisks, etc.
  06/10/01 Added flgets routine to help with platform-independent
           detection of invalid line-ends. All PG text files should
           have CR/LF (13/10) at end of line, regardless of system.
           Gutcheck now validates this by default. (Thanks, Charles!)
           Released as .13

           ---------------

  06/11/01 Added parenthesis match checking. (c_brack, cbrack_err etc.)
           Released as .14

           ---------------

  06/23/01 Fixed: 'No',he said. not being flagged.

           Improved: better single-quotes checking:

           Ignore singlequotes surrounded by alpha, like didn't. (was OK)

           If a singlequote is at the END of a word AND the word ends in "s":
                  The dogs' tails wagged.
           it's probably an apostrophe, but less commonly may be a closequote:
                  "These 'pack dogs' of yours look more like wolves."

           If it's got punctuation before it and is followed by a space
           or punctuation:
              . . . was a problem,' he said
              . . . was a problem,'"
           it is probably (certainly?) a closequote.

           If it's at start of paragraph, it's probably an openquote.
              (but watch dialect)

           Words with ' at beginning and end are probably quoted:
               "You have the word 'chivalry' frequently on your lips."
               (Not specifically implemented)
           V.18 I'm glad I didn't implement this, 'cos it jest ain't so
           where the convention is to punctuate outside the quotes.
               'Come', he said, 'and join the party'.

           If it is followed by an alpha, and especially a capital:
              'Hello,' called he.
           it is either an openquote or dialect.

           Dialect breaks ALL the rules:
                  A man's a man for a' that.
                  "Aye, but 'tis all in the pas' now."
                  "'Tis often the way," he said.
                  'Ave a drink on me.

           This version looks to be an improvement, and produces
           fewer false positives, but is still not perfect. The
           'pack dogs' case still fools it, and dialect is still
           a problem. Oh, well, it's an improvement, and I have
           a weighted structure in place for refining guesses at
           closequotes. Maybe next time, I'll add a bit of logic
           where if there is an open quote and one that was guessed
           to be a possessive apostrophe after s, I'll re-guess it
           to be a closequote. Let's see how this one flies, first.

           (Afterview: it's still crap. Needs much work, and a deeper insight.)

           Released as .15

           TODO: More he/be checks. Can't be perfect - counterexamples:
              I gave my son good advice: be married regardless of the world's opinion.
              I gave my son good advice: he married regardless of the world's opinion.

              If by "primitive" be meant "crude", we can understand the sentence.
              If by "primitive" he meant "crude", we can understand the sentence.

              No matter what be said, I must go on.
              No matter what he said, I must go on.

              No value, however great, can be set upon them.
              No value, however great, can he set upon them.

              Real-Life one from a DP International Weekly Miscellany:
                He wandered through the forest without fear, sleeping
                much, for in sleep be had companionship--the Great
                Spirit teaching him what he should know in dreams.
                That one found by jeebies, and it turned out to be "he".


           ---------------

  07/01/01 Added -O option.
           Improved singlequotes by reporting mismatched single quotes
           only if an open_single_quotes was found.

           Released as .16

           ---------------

  08/27/01 Added -Y switch for Robert Rowe to allow his app to
           catch the error output.

           Released as .17

           ---------------

  09/08/01 Added checking Capitals at start of paragraph, but not
           checking them at start of sentence.

           TODO: Parse sentences out so can check reliably for start of
                 sentence. Need a whole different approach for that.
                 (Can't just rely on periods, since they are also
                 used for abbreviations, etc.)

           Added checking for all vowels or all consonants in a word.

           While I was in, I added "ii" checking and "tl" at start of word.

           Added echoing of first line of paragraph when reporting
           mismatched quoted or brackets (thanks to David Widger for the
           suggestion)

           Not querying L at start of a number (used for British pounds).

           The spelling changes are sort of half-done but released anyway
           Skipped .18 because I had given out a couple of test versions
           with that number.

  09/25/01 Released as .19

           ---------------

           TODO:
           Use the logic from my new version of safewrap to stop querying
             short lines like poems and TOCs.
           Ignore non-standard ellipses like .  .  . or ...


           ---------------
  10/01/01 Made any line over 80 a VERY long line (was 85).
           Recognized openquotes on indented paragraphs as continuations
               of the same speech.
           Added "cf" to the okword list (how did I forget _that_?) and a few others.
           Moved abbrev to okword and made it more general.
           Removed requirement that PG_space_emdash be greater than
               ten before turning off warnings about spaced dashes.
           Added period to list of characters that might constitute a separator line.
           Now checking for double punctuation (Thanks, David!)
           Now if two spaced em-dashes on a line, reports both. (DW)
           Bug: Wasn't catching spaced punctuation at line-end since I
               added flgets in version .13 - fixed.
           Bug: Wasn't catching spaced singlequotes - fixed
           Now reads punctuated numbers like 1,000 as a single word.
               (Used to give "standalone 1" type  queries)
           Changed paranoid mode - not including s and p options. -ex is now quite usable.
           Bug: was calling `"For it is perfectly impossible,"    Unspaced Quotes - fixed
           Bug: Sometimes gave _next_ line number for queried word at end of line - fixed

  10/22/01 Released as .20

           ---------------

           Added count of lines with spaces at end. (cnt_spacend) (Thanks, Brett!)
           Reduced the number of hi-bit letters needed to stop reporting them
               from 1/20 to 1/100 or 200 in total.
           Added PG footer check.
           Added the -h switch.
           Fixed platform-specific CHAR_EOL checking for isemptyline - changed to 13 and 10
           Not reporting ".," when there are many of them, such as a book with many references to "Vol 1., p. 23"
           Added unspaced brackets check when surrounded by alpha.
           Removed all typo reporting unless the typo switch is on.
           Added gcisalpha to ease over-reporting of 8-bit queries.
           ECHO_SWITCH is now ON by default!
           PARANOID_SWITCH is now ON by default!
           Checking for ">From" placed there by e-mail MTA (Thanks Andrew & Greg)
           Checking for standalone lowercase "l"
           Checking for standalone lowercase "s"
           Considering "is be" and "be is" "be was" "was be" as he/be errors
           Looking at punct at end of para

  01/20/02 Released as .21

           ---------------

           Added VERBOSE_SWITCH to make it list everything. (George Davis)

           ---------------

  02/17/02 Added cint in flgets to try fix an EOF failure on a compiler I don't have.
           after which
           This line caused a coredump on Solaris - fixed.
                Da sagte die Figur: " Das ist alles gar schoen, und man mag die Puppe
  03/09/02 Changed header recognition for another header change
           Called it .24
  03/29/02 Added qword[][] so I can suppress massive overreporting
           of queried "words" like "FN", "Wm.", "th'", people's 
           initials, chemical formulae and suchlike in some texts.
           Called it .25
  04/07/02 The qword summary reports at end shouldn't show in OVERVIEW mode. Fixed.
           Added linecounts in overview mode.
           Wow! gutcheck gutcheck.exe doesn't report a binary! :-) Need to tighten up. Done.
           "m" is a not uncommon scanno for "in", but also appears in "a.m." - Can I get round that?
  07/07/02 Added GPL.
           Added checking for broken em-dash at line-end (enddash)
           Released as 0.95
  08/17/02 Fixed a bug that treated some hi-bit characters as spaces. Thanks, Carlo.
           Released as 0.96
  10/10/02 Suppressing some annoying multiple reports by default:
           Standalone Ones, Asterisks, Square Brackets.
              Digit 1 occurs often in many scientific texts.
              Asterisk occurs often in multi-footnoted texts.
              Mismatch Square Brackets occurs often in multi-para footnotes.
           Added -m switch for Charlz. Horrible. Nasty. Kludgy. Evil.
              . . . but it does more or less work for the main cases.
           Removed uppercase within a word as a separate category so
           that names like VanAllen get reported only once, like other
           suspected typos.
  11/24/02 Fixed - -m switch wasn't looking at htmlnum in
           loseentities (Thanks, Brett!)
           Fixed bug which occasionally gave false warning of
           paragraph starting with lowercase.
           Added underscore as character not to query around doublequotes.
           Split the "Non-ASCII" message into "Non-ASCII" vs. "Non-ISO-8859"
           . . . this is to help detect things like CP1252 characters.
           Released as 0.97

  12/01/02 Hacked a simplified version of the "Wrongspaced quotes" out of gutspell,
           for doublequotes only. Replaces "Spaced quote", since it also covers that
           case.
           Added "warn_hyphen" to ease over-reporting of hyphens.

  12/20/02 Added "extra period" checks.
           Added single character line check
           Added I" check - is usually an exclam
           Released as 0.98

  1/5/03   Eeek! Left in a lowerit(argv[0]) at the start before procfile()
           from when I was looking at ways to identify markup. Refuses to
           open files for *nix users with upcase in the filemanes. Removed.
           Fixed quickly and released as 0.981

  1/8/03   Added "arid" to the list of typos, slightly against my better
           judgement, but the DP gang are all excited about it. :-)
           Added a check for comma followed by capital letter, where
           a period has OCRed into a comma. (DW). Not sure about this
           either; we'll see.
           Compiling for Win32 to allow longfilenames.

  6/1/04   A messy test release for DW to include the "gutcheck.typ"
           process. And the gutcheck.jee trials. Removed "arid" --
           it can go in gutcheck.typ

           Added checks for carats ^ and slants / but disabling slant
           queries if more than 20 of them, because some people use them
           for /italics/. Slants are commonly mistaken italic "I"s.

           Later: removed gutcheck.jee -- wrote jeebies instead.

Random TODO: 
           Check brackets more closely, like quotes, so that it becomes
           easy to find the error in long paragraphs full of brackets.


  1/2/05   Has it really been that long? Added "nocomma", "noperiod" check.
           Bits and pieces: improved isroman(). Added isletter().
           Other stuff I never noted before this.

  7/3/05   Stuck in a quick start on DP-markup ignoring 
           at BillFlis's suggestion.

  11/4/04  Assorted cleanup. Fixed case where text started with an
           unbalanced paragraph.



1       I
ail     all
arc     are
arid    and
bad     had
ball    hall
band    hand
bar     her
bat     but
be      he
bead    head
beads   heads
bear    hear
bit     hit
bo      be
boon    been
borne   home
bow     how
bumbled humbled
car     ear
carnage carriage
carne   came
cast    east
cat     cut
cat     eat
cheek   check
clay    day
coining coming
comer   corner
die     she
docs    does
ease    case
fail    fall
fee     he
haying  having
ho      he
ho      who
hut     but
is      as
lie     he
lime    time
loth    10th
m       in
modem   modern
Ms      his
ray     away
ray     my
ringer  finger
ringers fingers
rioted  noted
tho     the
tie     he
tie     the
tier    her
tight   right
tile    the
tiling  thing
tip     up
tram    train
tune    time
u       "
wen     well
yon     you

*********************************************************************/

