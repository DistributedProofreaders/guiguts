/*************************************************************************/
/* bookloupe--check for assorted weirdnesses in a PG candidate text file */
/*									 */
/* Copyright 2000-2005 Jim Tinsley <jtinsley@pobox.com>			 */
/* Copyright 2012- J. Ali Harlow <ali@juiblex.co.uk>			 */
/*									 */
/* This program is free software; you can redistribute it and/or modify  */
/* it under the terms of the GNU General Public License as published by  */
/* the Free Software Foundation; either version 2 of the License, or     */
/* (at your option) any later version.					 */
/*									 */
/* This program is distributed in the hope that it will be useful,       */
/* but WITHOUT ANY WARRANTY; without even the implied warranty of	 */
/* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the		 */
/* GNU General Public License for more details.				 */
/*									 */
/* You should have received a copy of the GNU General Public License	 */
/* along with this program. If not, see <http://www.gnu.org/licenses/>.	 */
/*************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#ifdef __WIN32__
#include <windows.h>
#endif
#include <glib.h>
#include <bl/bl.h>
#include "HTMLentities.h"

gchar *prevline;

/* Common typos. */
char *typo[] = {
    "teh", "th", "og", "fi", "ro", "adn", "yuo", "ot", "fo", "thet", "ane",
    "nad", "te", "ig", "acn",  "ahve", "alot", "anbd", "andt", "awya", "aywa",
    "bakc", "om", "btu", "byt", "cna", "cxan", "coudl", "dont", "didnt",
    "couldnt", "wouldnt", "doesnt", "shouldnt", "doign", "ehr", "hmi", "hse",
    "esle", "eyt", "fitrs", "firts", "foudn", "frmo", "fromt", "fwe", "gaurd",
    "gerat", "goign", "gruop", "haev", "hda", "hearign", "seeign", "sayign",
    "herat", "hge", "hsa", "hsi", "hte", "htere", "htese", "htey", "htis",
    "hvae", "hwich", "idae", "ihs", "iits", "int", "iwll", "iwth", "jsut",
    "loev", "sefl", "myu", "nkow", "nver", "nwe", "nwo", "ocur", "ohter",
    "omre", "onyl", "otehr", "otu", "owrk", "owuld", "peice", "peices",
    "peolpe", "peopel", "perhasp", "perhpas", "pleasent", "poeple", "porblem",
    "porblems", "rwite", "saidt", "saidh", "saids", "seh", "smae", "smoe",
    "sohw", "stnad", "stopry", "stoyr", "stpo", "tahn", "taht", "tath",
    "tehy", "tghe", "tghis", "theri", "theyll", "thgat", "thge", "thier",
    "thna", "thne", "thnig", "thnigs", "thsi", "thsoe", "thta", "timne",
    "tirne", "tkae", "tthe", "tyhat", "tyhe", "veyr", "vou", "vour", "vrey",
    "waht", "wasnt", "awtn", "watn", "wehn", "whic", "whcih", "whihc", "whta",
    "wihch", "wief", "wiht", "witha", "wiull", "wnat", "wnated", "wnats",
    "woh", "wohle", "wokr", "woudl", "wriet", "wrod", "wroet", "wroking",
    "wtih", "wuould", "wya", "yera", "yeras", "yersa", "yoiu", "youve",
    "ytou", "yuor", "abead", "ahle", "ahout", "ahove", "altbough", "balf",
    "bardly", "bas", "bave", "baving", "bebind", "beld", "belp", "belped",
    "ber", "bere", "bim", "bis", "bome", "bouse", "bowever", "buge",
    "dehates", "deht", "han", "hecause", "hecome", "heen", "hefore", "hegan",
    "hegin", "heing", "helieve", "henefit", "hetter", "hetween", "heyond",
    "hig", "higber", "huild", "huy", "hy", "jobn", "joh", "meanwbile",
    "memher", "memhers", "numher", "numhers", "perbaps", "prohlem", "puhlic",
    "witbout", "arn", "hin", "hirn", "wrok", "wroked", "amd", "aud",
    "prornise", "prornised", "modem", "bo", "heside", "chapteb", "chaptee",
    "se", ""
};

GTree *usertypo;

/* Common abbreviations and other OK words not to query as typos. */
char *okword[] = {
    "mr", "mrs", "mss", "mssrs", "ft", "pm", "st", "dr", "hmm", "h'm", "hmmm",
    "rd", "sh", "br", "pp", "hm", "cf", "jr", "sr", "vs", "lb", "lbs", "ltd",
    "pompeii","hawaii","hawaiian", "hotbed", "heartbeat", "heartbeats",
    "outbid", "outbids", "frostbite", "frostbitten", ""
};

/* Common abbreviations that cause otherwise unexplained periods. */
char *abbrev[] = {
    "cent", "cents", "viz", "vol", "vols", "vid", "ed", "al", "etc", "op",
    "cit", "deg", "min", "chap", "oz", "mme", "mlle", "mssrs", ""
};

/*
 * Two-Letter combinations that rarely if ever start words,
 * but are common scannos or otherwise common letter combinations.
 */
char *nostart[] = {
    "hr", "hl", "cb", "sb", "tb", "wb", "tl", "tn", "rn", "lt", "tj", ""
};

/*
 * Two-Letter combinations that rarely if ever end words,
 * but are common scannos or otherwise common letter combinations.
 */
char *noend[] = {
    "cb", "gb", "pb", "sb", "tb", "wh", "fr", "br", "qu", "tw", "gl", "fl",
    "sw", "gr", "sl", "cl", "iy", ""
};

char *markup[] = {
    "a", "b", "big", "blockquote", "body", "br", "center", "col", "div", "em",
    "font", "h1", "h2", "h3", "h4", "h5", "h6", "head", "hr", "html", "i",
    "img", "li", "meta", "ol", "p", "pre", "small", "span", "strong", "sub",
    "sup", "table", "td", "tfoot", "thead", "title", "tr", "tt", "u", "ul", ""
};

char *DPmarkup[] = {
    "<sc>", "</sc>", "/*", "*/", "/#", "#/", "/$", "$/", "<tb>", ""
};

char *nocomma[] = {
    "the", "it's", "their", "an", "mrs", "a", "our", "that's", "its", "whose",
    "every", "i'll", "your", "my", "mr", "mrs", "mss", "mssrs", "ft", "pm",
    "st", "dr", "rd", "pp", "cf", "jr", "sr", "vs", "lb", "lbs", "ltd", "i'm",
    "during", "let", "toward", "among", ""
};

char *noperiod[] = {
    "every", "i'm", "during", "that's", "their", "your", "our", "my", "or",
    "and", "but", "as", "if", "the", "its", "it's", "until", "than", "whether",
    "i'll", "whose", "who", "because", "when", "let", "till", "very", "an",
    "among", "those", "into", "whom", "having", "thence", ""
}; 

/* special characters */
#define CHAR_SPACE	  32
#define CHAR_TAB	   9
#define CHAR_LF		  10
#define CHAR_CR		  13
#define CHAR_DQUOTE	  34
#define CHAR_SQUOTE	  39
#define CHAR_OPEN_SQUOTE  96
#define CHAR_TILDE	 126
#define CHAR_ASTERISK	  42
#define CHAR_FORESLASH	  47
#define CHAR_CARAT	  94

#define CHAR_UNDERSCORE    '_'
#define CHAR_OPEN_CBRACK   '{'
#define CHAR_CLOSE_CBRACK  '}'
#define CHAR_OPEN_RBRACK   '('
#define CHAR_CLOSE_RBRACK  ')'
#define CHAR_OPEN_SBRACK   '['
#define CHAR_CLOSE_SBRACK  ']'

/* longest and shortest normal PG line lengths */
#define LONGEST_PG_LINE   75
#define WAY_TOO_LONG      80
#define SHORTEST_PG_LINE  55

enum {
    ECHO_SWITCH,
    SQUOTE_SWITCH,
    TYPO_SWITCH,
    QPARA_SWITCH,
    PARANOID_SWITCH,
    LINE_END_SWITCH,
    OVERVIEW_SWITCH,
    STDOUT_SWITCH,
    HEADER_SWITCH,
    WEB_SWITCH,
    VERBOSE_SWITCH,
    MARKUP_SWITCH,
    USERTYPO_SWITCH,
    DP_SWITCH,
    SWITNO
};

gboolean pswit[SWITNO];  /* program switches */

static GOptionEntry options[]={
    { "dp", 'd', 0, G_OPTION_ARG_NONE, pswit+DP_SWITCH,
      "Ignore DP-specific markup", NULL },
    { "noecho", 'e', 0, G_OPTION_ARG_NONE, pswit+ECHO_SWITCH,
      "Don't echo queried line", NULL },
    { "squote", 's', 0, G_OPTION_ARG_NONE, pswit+SQUOTE_SWITCH,
      "Check single quotes", NULL },
    { "typo", 't', 0, G_OPTION_ARG_NONE, pswit+TYPO_SWITCH,
      "Check common typos", NULL },
    { "qpara", 'p', 0, G_OPTION_ARG_NONE, pswit+QPARA_SWITCH,
      "Require closure of quotes on every paragraph", NULL },
    { "relaxed", 'x', 0, G_OPTION_ARG_NONE, pswit+PARANOID_SWITCH,
      "Disable paranoid querying of everything", NULL },
    { "line-end", 'l', 0, G_OPTION_ARG_NONE, pswit+LINE_END_SWITCH,
      "Disable line end checking", NULL },
    { "overview", 'o', 0, G_OPTION_ARG_NONE, pswit+OVERVIEW_SWITCH,
      "Overview: just show counts", NULL },
    { "stdout", 'y', 0, G_OPTION_ARG_NONE, pswit+STDOUT_SWITCH,
      "Output errors to stdout instead of stderr", NULL },
    { "header", 'h', 0, G_OPTION_ARG_NONE, pswit+HEADER_SWITCH,
      "Echo header fields", NULL },
    { "markup", 'm', 0, G_OPTION_ARG_NONE, pswit+MARKUP_SWITCH,
      "Ignore markup in < >", NULL },
    { "usertypo", 'u', 0, G_OPTION_ARG_NONE, pswit+USERTYPO_SWITCH,
      "Use file of user-defined typos", NULL },
    { "web", 'w', 0, G_OPTION_ARG_NONE, pswit+WEB_SWITCH,
      "Defaults for use on www upload", NULL },
    { "verbose", 'v', 0, G_OPTION_ARG_NONE, pswit+VERBOSE_SWITCH,
      "Verbose - list everything", NULL },
    { NULL }
};

long cnt_dquot;		/* for overview mode, count of doublequote queries */
long cnt_squot;		/* for overview mode, count of singlequote queries */
long cnt_brack;		/* for overview mode, count of brackets queries */
long cnt_bin;		/* for overview mode, count of non-ASCII queries */
long cnt_odd;		/* for overview mode, count of odd character queries */
long cnt_long;		/* for overview mode, count of long line errors */
long cnt_short;		/* for overview mode, count of short line queries */
long cnt_punct;		/* for overview mode,
			   count of punctuation and spacing queries */
long cnt_dash;		/* for overview mode, count of dash-related queries */
long cnt_word;		/* for overview mode, count of word queries */
long cnt_html;		/* for overview mode, count of html queries */
long cnt_lineend;	/* for overview mode, count of line-end queries */
long cnt_spacend;	/* count of lines with space at end */
long linecnt;		/* count of total lines in the file */
long checked_linecnt;	/* count of lines actually checked */

void proghelp(GOptionContext *context);
void procfile(const char *);

gchar *running_from;

gboolean mixdigit(const char *);
gchar *getaword(const char **);
char *flgets(char **,long);
void postprocess_for_HTML(char *);
char *linehasmarkup(char *);
char *losemarkup(char *);
gboolean tagcomp(const char *,const char *);
void loseentities(char *);
gboolean isroman(const char *);
void postprocess_for_DP(char *);
void print_as_windows_1252(const char *string);
void print_as_utf_8(const char *string);

GTree *qword,*qperiod;

#ifdef __WIN32__
UINT saved_cp;
#endif

struct first_pass_results {
    long firstline,astline;
    long footerline,totlen,binlen,alphalen,endquote_count,shortline,dotcomma;
    long fslashline,hyphens,longline,verylongline,htmcount,standalone_digit;
    long spacedash,emdash,space_emdash,non_PG_space_emdash,PG_space_emdash;
    int Dutchcount,Frenchcount;
};

struct warnings {
    int shortline,longline,bin,dash,dotcomma,ast,fslash,digit,hyphen;
    int endquote;
    gboolean isDutch,isFrench;
};

struct counters {
    long quot;
    int c_unders,c_brack,s_brack,r_brack;
    int open_single_quote,close_single_quote;
};

struct line_properties {
    unsigned int len,blen;
    gunichar start;
};

struct parities {
    int dquote,squote;
};

struct pending {
    char *dquote,*squote,*rbrack,*sbrack,*cbrack,*unders;
    long squot;
};

void parse_options(int *argc,char ***argv)
{
    GError *err=NULL;
    GOptionContext *context;
    context=g_option_context_new(
      "file - looks for errors in Project Gutenberg(TM) etexts");
    g_option_context_add_main_entries(context,options,NULL);
    if (!g_option_context_parse(context,argc,argv,&err))
    {
	g_printerr("Bookloupe: %s\n",err->message);
	g_printerr("Use \"%s --help\" for help\n",(*argv)[0]);
	exit(1);
    }
    /* Paranoid checking is turned OFF, not on, by its switch */
    pswit[PARANOID_SWITCH]=!pswit[PARANOID_SWITCH];
    if (pswit[PARANOID_SWITCH])
	/* if running in paranoid mode, typo checks default to enabled */
	pswit[TYPO_SWITCH]=!pswit[TYPO_SWITCH];
    /* Line-end checking is turned OFF, not on, by its switch */
    pswit[LINE_END_SWITCH]=!pswit[LINE_END_SWITCH];
    /* Echoing is turned OFF, not on, by its switch */
    pswit[ECHO_SWITCH]=!pswit[ECHO_SWITCH];
    if (pswit[OVERVIEW_SWITCH])
	/* just print summary; don't echo */
	pswit[ECHO_SWITCH]=FALSE;
    /*
     * Web uploads - for the moment, this is really just a placeholder
     * until we decide what processing we really want to do on web uploads
     */
    if (pswit[WEB_SWITCH])
    {
	/* specific override for web uploads */
	pswit[ECHO_SWITCH]=TRUE;
	pswit[SQUOTE_SWITCH]=FALSE;
	pswit[TYPO_SWITCH]=TRUE;
	pswit[QPARA_SWITCH]=FALSE;
	pswit[PARANOID_SWITCH]=TRUE;
	pswit[LINE_END_SWITCH]=FALSE;
	pswit[OVERVIEW_SWITCH]=FALSE;
	pswit[STDOUT_SWITCH]=FALSE;
	pswit[HEADER_SWITCH]=TRUE;
	pswit[VERBOSE_SWITCH]=FALSE;
	pswit[MARKUP_SWITCH]=FALSE;
	pswit[USERTYPO_SWITCH]=FALSE;
	pswit[DP_SWITCH]=FALSE;
    }
    if (*argc<2)
    {
	proghelp(context);
	exit(1);
    }
    g_option_context_free(context);
}

/*
 * read_user_scannos:
 *
 * Read in the user-defined stealth scanno list.
 */
void read_user_scannos(void)
{
    GError *err=NULL;
    gchar *usertypo_file;
    gboolean okay;
    int i;
    gsize len,nb;
    gchar *contents,*utf8,**lines;
    usertypo_file=g_strdup("bookloupe.typ");
    okay=file_get_contents_text(usertypo_file,&contents,&len,&err);
    if (g_error_matches(err,G_FILE_ERROR,G_FILE_ERROR_NOENT))
    {
	g_clear_error(&err);
	g_free(usertypo_file);
	usertypo_file=g_build_filename(running_from,"bookloupe.typ",NULL);
	okay=file_get_contents_text(usertypo_file,&contents,&len,&err);
    }
    if (g_error_matches(err,G_FILE_ERROR,G_FILE_ERROR_NOENT))
    {
	g_clear_error(&err);
	g_free(usertypo_file);
	usertypo_file=g_strdup("gutcheck.typ");
	okay=file_get_contents_text(usertypo_file,&contents,&len,&err);
    }
    if (g_error_matches(err,G_FILE_ERROR,G_FILE_ERROR_NOENT))
    {
	g_clear_error(&err);
	g_free(usertypo_file);
	usertypo_file=g_build_filename(running_from,"gutcheck.typ",NULL);
	okay=file_get_contents_text(usertypo_file,&contents,&len,&err);
    }
    if (g_error_matches(err,G_FILE_ERROR,G_FILE_ERROR_NOENT))
    {
	g_free(usertypo_file);
	g_print("   --> I couldn't find bookloupe.typ "
	  "-- proceeding without user typos.\n");
	return;
    }
    else if (!okay)
    {
	fprintf(stderr,"%s: %s\n",usertypo_file,err->message);
	g_free(usertypo_file);
	g_clear_error(&err);
	exit(1);
    }
    if (g_utf8_validate(contents,len,NULL))
	utf8=g_utf8_normalize(contents,len,G_NORMALIZE_DEFAULT_COMPOSE);
    else
	utf8=g_convert(contents,len,"UTF-8","WINDOWS-1252",NULL,&nb,NULL);
    g_free(contents);
    lines=g_strsplit_set(utf8,"\r\n",0);
    g_free(utf8);
    usertypo=g_tree_new_full((GCompareDataFunc)strcmp,NULL,g_free,NULL);
    for (i=0;lines[i];i++)
	if (*(unsigned char *)lines[i]>'!')
	    g_tree_insert(usertypo,lines[i],GINT_TO_POINTER(1));
	else
	    g_free(lines[i]);
    g_free(lines);
}

/*
 * read_etext:
 *
 * Read an etext returning a newly allocated string containing the file
 * contents or NULL on error.
 */
gchar *read_etext(const char *filename,GError **err)
{
    GError *tmp_err=NULL;
    gchar *contents,*utf8;
    gsize len,bytes_read,bytes_written;
    int i,line,col;
    if (!g_file_get_contents(filename,&contents,&len,err))
	return NULL;
    if (g_utf8_validate(contents,len,NULL))
    {
	utf8=g_utf8_normalize(contents,len,G_NORMALIZE_DEFAULT_COMPOSE);
	g_set_print_handler(print_as_utf_8);
#ifdef __WIN32__
	SetConsoleOutputCP(CP_UTF8);
#endif
    }
    else
    {
	utf8=g_convert(contents,len,"UTF-8","WINDOWS-1252",&bytes_read,
	  &bytes_written,&tmp_err);
	if (g_error_matches(tmp_err,G_CONVERT_ERROR,
	  G_CONVERT_ERROR_ILLEGAL_SEQUENCE))
	{
	    line=col=1;
	    for(i=0;i<bytes_read;i++)
		if (contents[i]=='\n')
		{
		    line++;
		    col=1;
		}
		else if (contents[i]!='\r')
		    col++;
	    g_set_error(err,G_CONVERT_ERROR,G_CONVERT_ERROR_ILLEGAL_SEQUENCE,
	      "Input conversion failed. Byte %d at line %d, column %d is not a "
	      "valid Windows-1252 character",
	      ((unsigned char *)contents)[bytes_read],line,col);
	}
	else if (tmp_err)
	    g_propagate_error(err,tmp_err);
	g_set_print_handler(print_as_windows_1252);
#ifdef __WIN32__
	SetConsoleOutputCP(1252);
#endif
    }
    g_free(contents);
    return utf8;
}

void cleanup_on_exit(void)
{
#ifdef __WIN32__
    SetConsoleOutputCP(saved_cp);
#endif
}

int main(int argc,char **argv)
{
#ifdef __WIN32__
    atexit(cleanup_on_exit);
    saved_cp=GetConsoleOutputCP();
#endif
    running_from=g_path_get_dirname(argv[0]);
    parse_options(&argc,&argv);
    if (pswit[USERTYPO_SWITCH])
	read_user_scannos();
    fprintf(stderr,"bookloupe: Check and report on an e-text\n");
    procfile(argv[1]);
    if (pswit[OVERVIEW_SWITCH])
    {
	g_print("    Checked %ld lines of %ld (head+foot = %ld)\n\n",
	  checked_linecnt,linecnt,linecnt-checked_linecnt);
	g_print("    --------------- Queries found --------------\n");
	if (cnt_long)
	    g_print("    Long lines:		    %14ld\n",cnt_long);
	if (cnt_short)
	    g_print("    Short lines:		   %14ld\n",cnt_short);
	if (cnt_lineend)
	    g_print("    Line-end problems:	     %14ld\n",cnt_lineend);
	if (cnt_word)
	    g_print("    Common typos:		  %14ld\n",cnt_word);
	if (cnt_dquot)
	    g_print("    Unmatched quotes:	      %14ld\n",cnt_dquot);
	if (cnt_squot)
	    g_print("    Unmatched SingleQuotes:	%14ld\n",cnt_squot);
	if (cnt_brack)
	    g_print("    Unmatched brackets:	    %14ld\n",cnt_brack);
	if (cnt_bin)
	    g_print("    Non-ASCII characters:	  %14ld\n",cnt_bin);
	if (cnt_odd)
	    g_print("    Proofing characters:	   %14ld\n",cnt_odd);
	if (cnt_punct)
	    g_print("    Punctuation & spacing queries: %14ld\n",cnt_punct);
	if (cnt_dash)
	    g_print("    Non-standard dashes:	   %14ld\n",cnt_dash);
	if (cnt_html)
	    g_print("    Possible HTML tags:	    %14ld\n",cnt_html);
	g_print("\n");
	g_print("    TOTAL QUERIES		  %14ld\n",
	  cnt_dquot+cnt_squot+cnt_brack+cnt_bin+cnt_odd+cnt_long+
	  cnt_short+cnt_punct+cnt_dash+cnt_word+cnt_html+cnt_lineend);
    }
    g_free(running_from);
    if (usertypo)
	g_tree_unref(usertypo);
    return 0;
}

/*
 * first_pass:
 *
 * Run a first pass - verify that it's a valid PG
 * file, decide whether to report some things that
 * occur many times in the text like long or short
 * lines, non-standard dashes, etc.
 */
struct first_pass_results *first_pass(const char *etext)
{
    gunichar laststart=CHAR_SPACE;
    const char *s;
    gchar *lc_line;
    int i,j,lbytes,llen;
    gchar **lines;
    unsigned int lastlen=0,lastblen=0;
    long spline=0,nspline=0;
    static struct first_pass_results results={0};
    gchar *inword;
    lines=g_strsplit(etext,"\n",0);
    for (j=0;lines[j];j++)
    {
	lbytes=strlen(lines[j]);
	while (lbytes>0 && lines[j][lbytes-1]=='\r')
	    lines[j][--lbytes]='\0';
	llen=g_utf8_strlen(lines[j],lbytes);
	linecnt++;
	if (strstr(lines[j],"*END") && strstr(lines[j],"SMALL PRINT") &&
	  (strstr(lines[j],"PUBLIC DOMAIN") || strstr(lines[j],"COPYRIGHT")))
	{
	    if (spline)
		g_print("   --> Duplicate header?\n");
	    spline=linecnt+1;   /* first line of non-header text, that is */
	}
	if (!strncmp(lines[j],"*** START",9) &&
	  strstr(lines[j],"PROJECT GUTENBERG"))
	{
	    if (nspline)
		g_print("   --> Duplicate header?\n");
	    nspline=linecnt+1;   /* first line of non-header text, that is */
	}
	if (spline || nspline)
	{
	    lc_line=g_utf8_strdown(lines[j],lbytes);
	    if (strstr(lc_line,"end") && strstr(lc_line,"project gutenberg"))
	    {
		if (strstr(lc_line,"end")<strstr(lc_line,"project gutenberg"))
		{
		    if (results.footerline)
		    {
			/* it's an old-form header - we can detect duplicates */
			if (!nspline)
			    g_print("   --> Duplicate footer?\n");
		    }
		    else
			results.footerline=linecnt;
		}
	    }
	    g_free(lc_line);
	}
	if (spline)
	    results.firstline=spline;
	if (nspline)
	    results.firstline=nspline;  /* override with new */
	if (results.footerline)
	    continue;    /* don't count the boilerplate in the footer */
	results.totlen+=llen;
	for (s=lines[j];*s;s=g_utf8_next_char(s))
	{
	    if (g_utf8_get_char(s)>127)
		results.binlen++;
	    if (g_unichar_isalpha(g_utf8_get_char(s)))
		results.alphalen++;
	    if (s>lines[j] && g_utf8_get_char(s)==CHAR_DQUOTE &&
	      isalpha(g_utf8_get_char(g_utf8_prev_char(s))))
		results.endquote_count++;
	}
	if (llen>2 && lastlen>2 && lastlen<SHORTEST_PG_LINE && lastblen>2 &&
	  lastblen>SHORTEST_PG_LINE && laststart!=CHAR_SPACE)
	    results.shortline++;
	if (lbytes>0 &&
	  g_utf8_get_char(g_utf8_prev_char(lines[j]+lbytes))<=CHAR_SPACE)
	    cnt_spacend++;
	if (strstr(lines[j],".,"))
	    results.dotcomma++;
	/* only count ast lines for ignoring purposes where there is */
	/* locase text on the line */
	if (strchr(lines[j],'*'))
	{
	    for (s=lines[j];*s;s=g_utf8_next_char(s))
		if (g_unichar_islower(g_utf8_get_char(s)))
		    break;
	    if (*s)
		results.astline++;
	}
	if (strchr(lines[j],'/'))
	    results.fslashline++;
	if (lbytes>0)
	{
	    for (s=g_utf8_prev_char(lines[j]+lbytes);
	      s>lines[j] && g_utf8_get_char(s)<=CHAR_SPACE;
	      s=g_utf8_prev_char(s))
		;
	    if (s>g_utf8_next_char(lines[j]) && g_utf8_get_char(s)=='-' &&
	      g_utf8_get_char(g_utf8_prev_char(s))!='-')
		results.hyphens++;
	}
	if (llen>LONGEST_PG_LINE)
	    results.longline++;
	if (llen>WAY_TOO_LONG)
	    results.verylongline++;
	if (strchr(lines[j],'<') && strchr(lines[j],'>'))
	{
	    i=(int)(strchr(lines[j],'>')-strchr(lines[j],'<')+1);
	    if (i>0)
		results.htmcount++;
	    if (strstr(lines[j],"<i>"))
		results.htmcount+=4; /* bonus marks! */
	}
	/* Check for spaced em-dashes */
	if (lines[j][0] && (s=strstr(g_utf8_next_char(lines[j]),"--")))
	{
	    results.emdash++;
	    if (s[-1]==CHAR_SPACE || s[2]==CHAR_SPACE)
		results.space_emdash++;
	    if (s[-1]==CHAR_SPACE && s[2]==CHAR_SPACE)
		/* count of em-dashes with spaces both sides */
		results.non_PG_space_emdash++;
	    if (s[-1]!=CHAR_SPACE && s[2]!=CHAR_SPACE)
		/* count of PG-type em-dashes with no spaces */
		results.PG_space_emdash++;
	}
	for (s=lines[j];*s;)
	{
	    inword=getaword(&s);
	    if (!strcmp(inword,"hij") || !strcmp(inword,"niet")) 
		results.Dutchcount++;
	    if (!strcmp(inword,"dans") || !strcmp(inword,"avec")) 
		results.Frenchcount++;
	    if (!strcmp(inword,"0") || !strcmp(inword,"1")) 
		results.standalone_digit++;
	    g_free(inword);
	}
	/* Check for spaced dashes */
	if (strstr(lines[j]," -") && *(strstr(lines[j]," -")+2)!='-')
	    results.spacedash++;
	lastblen=lastlen;
	lastlen=llen;
	laststart=lines[j][0];
    }
    g_strfreev(lines);
    return &results;
}

/*
 * report_first_pass:
 *
 * Make some snap decisions based on the first pass results.
 */
struct warnings *report_first_pass(struct first_pass_results *results)
{
    static struct warnings warnings={0};
    if (cnt_spacend>0)
	g_print("   --> %ld lines in this file have white space at end\n",
	  cnt_spacend);
    warnings.dotcomma=1;
    if (results->dotcomma>5)
    {
	warnings.dotcomma=0;
	g_print("   --> %ld lines in this file contain '.,'. "
	  "Not reporting them.\n",results->dotcomma);
    }
    /*
     * If more than 50 lines, or one-tenth, are short,
     * don't bother reporting them.
     */
    warnings.shortline=1;
    if (results->shortline>50 || results->shortline*10>linecnt)
    {
	warnings.shortline=0;
	g_print("   --> %ld lines in this file are short. "
	  "Not reporting short lines.\n",results->shortline);
    }
    /*
     * If more than 50 lines, or one-tenth, are long,
     * don't bother reporting them.
     */
    warnings.longline=1;
    if (results->longline>50 || results->longline*10>linecnt)
    {
	warnings.longline=0;
	g_print("   --> %ld lines in this file are long. "
	  "Not reporting long lines.\n",results->longline);
    }
    /* If more than 10 lines contain asterisks, don't bother reporting them. */
    warnings.ast=1;
    if (results->astline>10)
    {
	warnings.ast=0;
	g_print("   --> %ld lines in this file contain asterisks. "
	  "Not reporting them.\n",results->astline);
    }
    /*
     * If more than 10 lines contain forward slashes,
     * don't bother reporting them.
     */
    warnings.fslash=1;
    if (results->fslashline>10)
    {
	warnings.fslash=0;
	g_print("   --> %ld lines in this file contain forward slashes. "
	  "Not reporting them.\n",results->fslashline);
    }
    /*
     * If more than 20 lines contain unpunctuated endquotes,
     * don't bother reporting them.
     */
    warnings.endquote=1;
    if (results->endquote_count>20)
    {
	warnings.endquote=0;
	g_print("   --> %ld lines in this file contain unpunctuated endquotes. "
	  "Not reporting them.\n",results->endquote_count);
    }
    /*
     * If more than 15 lines contain standalone digits,
     * don't bother reporting them.
     */
    warnings.digit=1;
    if (results->standalone_digit>10)
    {
	warnings.digit=0;
	g_print("   --> %ld lines in this file contain standalone 0s and 1s. "
	  "Not reporting them.\n",results->standalone_digit);
    }
    /*
     * If more than 20 lines contain hyphens at end,
     * don't bother reporting them.
     */
    warnings.hyphen=1;
    if (results->hyphens>20)
    {
	warnings.hyphen=0;
	g_print("   --> %ld lines in this file have hyphens at end. "
	  "Not reporting them.\n",results->hyphens);
    }
    if (results->htmcount>20 && !pswit[MARKUP_SWITCH])
    {
	g_print("   --> Looks like this is HTML. Switching HTML mode ON.\n");
	pswit[MARKUP_SWITCH]=1;
    }
    if (results->verylongline>0)
	g_print("   --> %ld lines in this file are VERY long!\n",
	  results->verylongline);
    /*
     * If there are more non-PG spaced dashes than PG em-dashes,
     * assume it's deliberate.
     * Current PG guidelines say don't use them, but older texts do,
     * and some people insist on them whatever the guidelines say.
     */
    warnings.dash=1;
    if (results->spacedash+results->non_PG_space_emdash>
      results->PG_space_emdash)
    {
	warnings.dash=0;
	g_print("   --> There are %ld spaced dashes and em-dashes. "
	  "Not reporting them.\n",
	  results->spacedash+results->non_PG_space_emdash);
    }
    /* If more than a quarter of characters are hi-bit, bug out. */
    warnings.bin=1;
    if (results->binlen*4>results->totlen)
    {
	g_print("   --> This file does not appear to be ASCII. "
	  "Terminating. Best of luck with it!\n");
	exit(1);
    }
    if (results->alphalen*4<results->totlen)
    {
	g_print("   --> This file does not appear to be text. "
	  "Terminating. Best of luck with it!\n");
	exit(1);
    }
    if (results->binlen*100>results->totlen || results->binlen>100)
    {
	g_print("   --> There are a lot of foreign letters here. "
	  "Not reporting them.\n");
	warnings.bin=0;
    }
    warnings.isDutch=FALSE;
    if (results->Dutchcount>50)
    {
	warnings.isDutch=TRUE;
	g_print("   --> This looks like Dutch - "
	  "switching off dashes and warnings for 's Middags case.\n");
    }
    warnings.isFrench=FALSE;
    if (results->Frenchcount>50)
    {
	warnings.isFrench=TRUE;
	g_print("   --> This looks like French - "
	  "switching off some doublepunct.\n");
    }
    if (results->firstline && results->footerline)
	g_print("    The PG header and footer appear to be already on.\n");
    else
    {
	if (results->firstline)
	    g_print("    The PG header is on - no footer.\n");
	if (results->footerline)
	    g_print("    The PG footer is on - no header.\n");
    }
    g_print("\n");
    if (pswit[VERBOSE_SWITCH])
    {
	warnings.bin=1;
	warnings.shortline=1;
	warnings.dotcomma=1;
	warnings.longline=1;
	warnings.dash=1;
	warnings.digit=1;
	warnings.ast=1;
	warnings.fslash=1;
	warnings.hyphen=1;
	warnings.endquote=1;
	g_print("   *** Verbose output is ON -- you asked for it! ***\n");
    }
    if (warnings.isDutch)
	warnings.dash=0;
    if (results->footerline>0 && results->firstline>0 &&
      results->footerline>results->firstline &&
      results->footerline-results->firstline<100)
    {
	g_print("   --> I don't really know where this text starts. \n");
	g_print("       There are no reference points.\n");
	g_print("       I'm going to have to report the header and footer "
	  "as well.\n");
	results->firstline=0;
    }
    return &warnings;
}

/*
 * analyse_quotes:
 *
 * Look along the line, accumulate the count of quotes, and see
 * if this is an empty line - i.e. a line with nothing on it
 * but spaces.
 * If line has just spaces, period, * and/or - on it, don't
 * count it, since empty lines with asterisks or dashes to
 * separate sections are common.
 *
 * Returns: TRUE if the line is empty.
 */
gboolean analyse_quotes(const char *aline,struct counters *counters)
{
    int guessquote=0;
    /* assume the line is empty until proven otherwise */
    gboolean isemptyline=TRUE;
    const char *s=aline,*sprev,*snext;
    gunichar c;
    sprev=NULL;
    while (*s)
    {
	snext=g_utf8_next_char(s);
	c=g_utf8_get_char(s);
	if (c==CHAR_DQUOTE)
	    counters->quot++;
	if (c==CHAR_SQUOTE || c==CHAR_OPEN_SQUOTE)
	{
	    if (s==aline)
	    {
		/*
		 * At start of line, it can only be an openquote.
		 * Hardcode a very common exception!
		 */
		if (!g_str_has_prefix(snext,"tis") &&
		  !g_str_has_prefix(snext,"Tis"))
		    counters->open_single_quote++;
	    }
	    else if (g_unichar_isalpha(g_utf8_get_char(sprev)) &&
	      g_unichar_isalpha(g_utf8_get_char(snext)))
		/* Do nothing! it's definitely an apostrophe, not a quote */
		;
	    /* it's outside a word - let's check it out */
	    else if (c==CHAR_OPEN_SQUOTE ||
	      g_unichar_isalpha(g_utf8_get_char(snext)))
	    {
		/* it damwell better BE an openquote */
		if (!g_str_has_prefix(snext,"tis") &&
		  !g_str_has_prefix(snext,"Tis"))
		    /* hardcode a very common exception! */
		    counters->open_single_quote++;
	    }
	    else
	    {
		/* now - is it a closequote? */
		guessquote=0;   /* accumulate clues */
		if (g_unichar_isalpha(g_utf8_get_char(sprev)))
		{
		    /* it follows a letter - could be either */
		    guessquote++;
		    if (g_utf8_get_char(sprev)=='s')
		    {
			/* looks like a plural apostrophe */
			guessquote-=3;
			if (g_utf8_get_char(snext)==CHAR_SPACE)
			    /* bonus marks! */
			    guessquote-=2;
		    }
		}
		/* it doesn't have a letter either side */
		else if (strchr(".?!,;:",g_utf8_get_char(sprev)) &&
		  strchr(".?!,;: ",g_utf8_get_char(snext)))
		    guessquote+=8; /* looks like a closequote */
		else
		    guessquote++;
		if (counters->open_single_quote>counters->close_single_quote)
		    /*
		     * Give it the benefit of some doubt,
		     * if a squote is already open.
		     */
		    guessquote++;
		else
		    guessquote--;
		if (guessquote>=0)
		    counters->close_single_quote++;
	    }
	}
	if (c!=CHAR_SPACE && c!='-' && c!='.' && c!=CHAR_ASTERISK &&
	  c!='\r' && c!='\n')
	    isemptyline=FALSE;  /* ignore lines like  *  *  *  as spacers */
	if (c==CHAR_UNDERSCORE)
	    counters->c_unders++;
	if (c==CHAR_OPEN_CBRACK)
	    counters->c_brack++;
	if (c==CHAR_CLOSE_CBRACK)
	    counters->c_brack--;
	if (c==CHAR_OPEN_RBRACK)
	    counters->r_brack++;
	if (c==CHAR_CLOSE_RBRACK)
	    counters->r_brack--;
	if (c==CHAR_OPEN_SBRACK)
	    counters->s_brack++;
	if (c==CHAR_CLOSE_SBRACK)
	    counters->s_brack--;
	sprev=s;
	s=snext;
    }
    return isemptyline;
}

/*
 * check_for_control_characters:
 *
 * Check for invalid or questionable characters in the line
 * Anything above 127 is invalid for plain ASCII, and
 * non-printable control characters should also be flagged.
 * Tabs should generally not be there.
 */
void check_for_control_characters(const char *aline)
{
    gunichar c;
    const char *s;
    for (s=aline;*s;s=g_utf8_next_char(s))
    {
	c=g_utf8_get_char(s);
	if (c<CHAR_SPACE && c!=CHAR_LF && c!=CHAR_CR && c!=CHAR_TAB)
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Control character %u\n",
		  linecnt,g_utf8_pointer_to_offset(s,aline)+1,c);
	    else
		cnt_bin++;
	}
    }
}

/*
 * check_for_odd_characters:
 *
 * Check for binary and other odd characters.
 */
void check_for_odd_characters(const char *aline,const struct warnings *warnings,
  gboolean isemptyline)
{
    /* Don't repeat multiple warnings on one line. */
    gboolean eNon_A=FALSE,eTab=FALSE,eTilde=FALSE;
    gboolean eCarat=FALSE,eFSlash=FALSE,eAst=FALSE;
    const char *s;
    gunichar c;
    for (s=aline;*s;s=g_utf8_next_char(s))
    {
	c=g_utf8_get_char(s);
	if (!eNon_A && (c<CHAR_SPACE && c!='\t' && c!='\n' || c>127))
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		if (c>127 && c<160 || c>255)
		    g_print("    Line %ld column %ld - "
		      "Non-ISO-8859 character %u\n",
		      linecnt,g_utf8_pointer_to_offset(aline,s)+1,c);
		else
		    g_print("    Line %ld column %ld - "
		      "Non-ASCII character %u\n",
		      linecnt,g_utf8_pointer_to_offset(aline,s)+1,c);
	    else
		cnt_bin++;
	    eNon_A=TRUE;
	}
	if (!eTab && c==CHAR_TAB)
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Tab character?\n",
		  linecnt,g_utf8_pointer_to_offset(aline,s)+1);
	    else
		cnt_odd++;
	    eTab=TRUE;
	}
	if (!eTilde && c==CHAR_TILDE)
	{
	    /*
	     * Often used by OCR software to indicate an
	     * unrecognizable character.
	     */
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Tilde character?\n",
		  linecnt,g_utf8_pointer_to_offset(aline,s)+1);
	    else
		cnt_odd++;
	    eTilde=TRUE;
	}
	if (!eCarat && c==CHAR_CARAT)
	{  
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Carat character?\n",
		  linecnt,g_utf8_pointer_to_offset(aline,s)+1);
	    else
		cnt_odd++;
	    eCarat=TRUE;
	}
	if (!eFSlash && c==CHAR_FORESLASH && warnings->fslash)
	{  
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Forward slash?\n",
		  linecnt,g_utf8_pointer_to_offset(aline,s)+1);
	    else
		cnt_odd++;
	    eFSlash=TRUE;
	}
	/*
	 * Report asterisks only in paranoid mode,
	 * since they're often deliberate.
	 */
	if (!eAst && pswit[PARANOID_SWITCH] && warnings->ast && !isemptyline &&
	  c==CHAR_ASTERISK)
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Asterisk?\n",
		  linecnt,g_utf8_pointer_to_offset(aline,s)+1);
	    else
		cnt_odd++;
	    eAst=TRUE;
	}
    }
}

/*
 * check_for_long_line:
 *
 * Check for line too long.
 */
void check_for_long_line(const char *aline)
{
    if (g_utf8_strlen(aline,-1)>LONGEST_PG_LINE)
    {
	if (pswit[ECHO_SWITCH])
	    g_print("\n%s\n",aline);
	if (!pswit[OVERVIEW_SWITCH])
	    g_print("    Line %ld column %ld - Long line %ld\n",
	      linecnt,g_utf8_strlen(aline,-1),g_utf8_strlen(aline,-1));
	else
	    cnt_long++;
    }
}

/*
 * check_for_short_line:
 *
 * Check for line too short.
 *
 * This one is a bit trickier to implement: we don't want to
 * flag the last line of a paragraph for being short, so we
 * have to wait until we know that our current line is a
 * "normal" line, then report the _previous_ line if it was too
 * short. We also don't want to report indented lines like
 * chapter heads or formatted quotations. We therefore keep
 * last->len as the length of the last line examined, and
 * last->blen as the length of the last but one, and try to
 * suppress unnecessary warnings by checking that both were of
 * "normal" length. We keep the first character of the last
 * line in last->start, and if it was a space, we assume that
 * the formatting is deliberate. I can't figure out a way to
 * distinguish something like a quoted verse left-aligned or
 * the header or footer of a letter from a paragraph of short
 * lines - maybe if I examined the whole paragraph, and if the
 * para has less than, say, 8 lines and if all lines are short,
 * then just assume it's OK? Need to look at some texts to see
 * how often a formula like this would get the right result.
 */
void check_for_short_line(const char *aline,const struct line_properties *last)
{
    if (g_utf8_strlen(aline,-1)>1 && last->len>1 &&
      last->len<SHORTEST_PG_LINE && last->blen>1 &&
      last->blen>SHORTEST_PG_LINE && last->start!=CHAR_SPACE)
    {
	if (pswit[ECHO_SWITCH])
	    g_print("\n%s\n",prevline);
	if (!pswit[OVERVIEW_SWITCH])
	    g_print("    Line %ld column %ld - Short line %ld?\n",
	      linecnt-1,g_utf8_strlen(prevline,-1),g_utf8_strlen(prevline,-1));
	else
	    cnt_short++;
    }
}

/*
 * check_for_starting_punctuation:
 *
 * Look for punctuation other than full ellipses at start of line.
 */
void check_for_starting_punctuation(const char *aline)
{
    if (*aline && g_utf8_strchr(".?!,;:",-1,g_utf8_get_char(aline)) &&
      !g_str_has_prefix(aline,". . ."))
    {
	if (pswit[ECHO_SWITCH])
	    g_print("\n%s\n",aline);
	if (!pswit[OVERVIEW_SWITCH])
	    g_print("    Line %ld column 1 - Begins with punctuation?\n",
	      linecnt);
	else
	    cnt_punct++;
    }
}

/*
 * check_for_spaced_emdash:
 *
 * Check for spaced em-dashes.
 *
 * We must check _all_ occurrences of "--" on the line
 * hence the loop - even if the first double-dash is OK
 * there may be another that's wrong later on.
 */
void check_for_spaced_emdash(const char *aline)
{
    const char *s,*t,*next;
    for (s=aline;t=strstr(s,"--");s=next)
    {
	next=g_utf8_next_char(g_utf8_next_char(t));
	if (t>aline && g_utf8_get_char(g_utf8_prev_char(t))==CHAR_SPACE ||
	  g_utf8_get_char(next)==CHAR_SPACE)
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Spaced em-dash?\n",
		  linecnt,g_utf8_pointer_to_offset(aline,t)+1);
	    else
		cnt_dash++;
	}
    }
}

/*
 * check_for_spaced_dash:
 *
 * Check for spaced dashes.
 */
void check_for_spaced_dash(const char *aline)
{
    const char *s;
    if ((s=strstr(aline," -")))
    {
	if (g_utf8_get_char(g_utf8_next_char(g_utf8_next_char(s)))!='-')
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Spaced dash?\n",
		  linecnt,g_utf8_pointer_to_offset(aline,s)+1);
	    else
		cnt_dash++;
	}
    }
    else if ((s=strstr(aline,"- ")))
    {
	if (s==aline || g_utf8_get_char(g_utf8_prev_char(s))!='-')
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Spaced dash?\n",
		  linecnt,g_utf8_pointer_to_offset(aline,s)+1);
	    else
		cnt_dash++;
	}
    }
}

/*
 * check_for_unmarked_paragraphs:
 *
 * Check for unmarked paragraphs indicated by separate speakers.
 *
 * May well be false positive:
 * "Bravo!" "Wonderful!" called the crowd.
 * but useful all the same.
 */
void check_for_unmarked_paragraphs(const char *aline)
{
    const char *s;
    s=strstr(aline,"\"  \"");
    if (!s)
	s=strstr(aline,"\" \"");
    if (s)
    {
	if (pswit[ECHO_SWITCH])
	    g_print("\n%s\n",aline);
	if (!pswit[OVERVIEW_SWITCH])
	    g_print("    Line %ld column %ld - "
	      "Query missing paragraph break?\n",
	      linecnt,g_utf8_pointer_to_offset(aline,s)+1);
	else
	    cnt_punct++;
    }
}

/*
 * check_for_jeebies:
 *
 * Check for "to he" and other easy h/b errors.
 *
 * This is a very inadequate effort on the h/b problem,
 * but the phrase "to he" is always an error, whereas "to
 * be" is quite common.
 * Similarly, '"Quiet!", be said.' is a non-be error
 * "to he" is _not_ always an error!:
 *       "Where they went to he couldn't say."
 * Another false positive:
 *       What would "Cinderella" be without the . . .
 * and another: "If he wants to he can see for himself."
 */
void check_for_jeebies(const char *aline)
{
    const char *s;
    s=strstr(aline," be could ");
    if (!s)
	s=strstr(aline," be would ");
    if (!s)
	s=strstr(aline," was be ");
    if (!s)
	s=strstr(aline," be is ");
    if (!s)
	s=strstr(aline," is be ");
    if (!s)
	s=strstr(aline,"\", be ");
    if (!s)
	s=strstr(aline,"\" be ");
    if (!s)
	s=strstr(aline,"\" be ");
    if (!s)
	s=strstr(aline," to he ");
    if (s)
    {
	if (pswit[ECHO_SWITCH])
	    g_print("\n%s\n",aline);
	if (!pswit[OVERVIEW_SWITCH])
	    g_print("    Line %ld column %ld - Query he/be error?\n",
	      linecnt,g_utf8_pointer_to_offset(aline,s)+1);
	else
	    cnt_word++;
    }
    s=strstr(aline," the had ");
    if (!s)
	s=strstr(aline," a had ");
    if (!s)
	s=strstr(aline," they bad ");
    if (!s)
	s=strstr(aline," she bad ");
    if (!s)
	s=strstr(aline," he bad ");
    if (!s)
	s=strstr(aline," you bad ");
    if (!s)
	s=strstr(aline," i bad ");
    if (s)
    {
	if (pswit[ECHO_SWITCH])
	    g_print("\n%s\n",aline);
	if (!pswit[OVERVIEW_SWITCH])
	    g_print("    Line %ld column %ld - Query had/bad error?\n",
	      linecnt,g_utf8_pointer_to_offset(aline,s)+1);
	else
	    cnt_word++;
    }
    s=strstr(aline,"; hut ");
    if (!s)
	s=strstr(aline,", hut ");
    if (s)
    {
	if (pswit[ECHO_SWITCH])
	    g_print("\n%s\n",aline);
	if (!pswit[OVERVIEW_SWITCH])
	    g_print("    Line %ld column %ld - Query hut/but error?\n",
	      linecnt,g_utf8_pointer_to_offset(aline,s)+1);
	else
	    cnt_word++;
    }
}

/*
 * check_for_mta_from:
 *
 * Special case - angled bracket in front of "From" placed there by an
 * MTA when sending an e-mail.
 */
void check_for_mta_from(const char *aline)
{
    const char *s;
    s=strstr(aline,">From");
    if (s)
    {
	if (pswit[ECHO_SWITCH])
	    g_print("\n%s\n",aline);
	if (!pswit[OVERVIEW_SWITCH])
	    g_print("    Line %ld column %ld - "
	      "Query angled bracket with From\n",
	      linecnt,g_utf8_pointer_to_offset(aline,s)+1);
	else
	    cnt_punct++;
    }
}

/*
 * check_for_orphan_character:
 *
 * Check for a single character line -
 * often an overflow from bad wrapping.
 */
void check_for_orphan_character(const char *aline)
{
    gunichar c;
    c=g_utf8_get_char(aline);
    if (c && !*g_utf8_next_char(aline))
    {
	if (c=='I' || c=='V' || c=='X' || c=='L' || g_unichar_isdigit(c))
	    ; /* Nothing - ignore numerals alone on a line. */
	else
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column 1 - Query single character line\n",
		  linecnt);
	    else
		cnt_punct++;
	}
    }
}

/*
 * check_for_pling_scanno:
 *
 * Check for I" - often should be !
 */
void check_for_pling_scanno(const char *aline)
{
    const char *s;
    s=strstr(aline," I\"");
    if (s)
    {
	if (pswit[ECHO_SWITCH])
	    g_print("\n%s\n",aline);
	if (!pswit[OVERVIEW_SWITCH])
	    g_print("    Line %ld column %ld - Query I=exclamation mark?\n",
	      linecnt,g_utf8_pointer_to_offset(aline,s));
	else
	    cnt_punct++;
    }
}

/*
 * check_for_extra_period:
 *
 * Check for period without a capital letter. Cut-down from gutspell.
 * Only works when it happens on a single line.
 */
void check_for_extra_period(const char *aline,const struct warnings *warnings)
{
    const char *s,*t,*s1;
    int i;
    gsize len;
    gboolean istypo;
    gchar *testword;
    gunichar *decomposition;
    if (pswit[PARANOID_SWITCH])
    {
	for (t=aline;t=strstr(t,". ");)
	{
	    if (t==aline)
	    {
		t=g_utf8_next_char(t);
		/* start of line punctuation is handled elsewhere */
		continue;
	    }
	    if (!g_unichar_isalpha(g_utf8_get_char(g_utf8_prev_char(t))))
	    {
		t=g_utf8_next_char(t);
		continue;
	    }
	    if (warnings->isDutch)
	    {
		/* For Frank & Jeroen -- 's Middags case */
		gunichar c2,c3,c4,c5;
		c2=g_utf8_get_char(g_utf8_offset_to_pointer(t,2));
		c3=g_utf8_get_char(g_utf8_offset_to_pointer(t,3));
		c4=g_utf8_get_char(g_utf8_offset_to_pointer(t,4));
		c5=g_utf8_get_char(g_utf8_offset_to_pointer(t,5));
		if (c2==CHAR_SQUOTE && g_unichar_islower(c3) &&
		  c4==CHAR_SPACE && g_unichar_isupper(c5))
		{
		    t=g_utf8_next_char(t);
		    continue;
		}
	    }
	    s1=g_utf8_next_char(g_utf8_next_char(t));
	    while (*s1 && !g_unichar_isalpha(g_utf8_get_char(s1)) &&
	      !isdigit(g_utf8_get_char(s1)))
		s1=g_utf8_next_char(s1);
	    if (g_unichar_islower(g_utf8_get_char(s1)))
	    {
		/* we have something to investigate */
		istypo=TRUE;
		/* so let's go back and find out */
		for (s1=g_utf8_prev_char(t);s1>=aline &&
		  (g_unichar_isalpha(g_utf8_get_char(s1)) ||
		  g_unichar_isdigit(g_utf8_get_char(s1)) ||
		  g_utf8_get_char(s1)==CHAR_SQUOTE &&
		  g_unichar_isalpha(g_utf8_get_char(g_utf8_next_char(s1))) &&
		  g_unichar_isalpha(g_utf8_get_char(g_utf8_prev_char(s1))));
		  s1=g_utf8_prev_char(s1))
		    ;
		s1=g_utf8_next_char(s1);
		s=strchr(s1,'.');
		if (s)
		    testword=g_strndup(s1,s-s1);
		else
		    testword=g_strdup(s1);
		for (i=0;*abbrev[i];i++)
		    if (!strcmp(testword,abbrev[i]))
			istypo=FALSE;
		if (g_unichar_isdigit(g_utf8_get_char(testword)))
		    istypo=FALSE;
		if (!*g_utf8_next_char(testword))
		    istypo=FALSE;
		if (isroman(testword))
		    istypo=FALSE;
		if (istypo)
		{
		    istypo=FALSE;
		    for (s=testword;*s;s=g_utf8_next_char(s))
		    {
			decomposition=g_unicode_canonical_decomposition(
			  g_utf8_get_char(s),&len);
			if (g_utf8_strchr("aeiou",-1,decomposition[0]))
			    istypo=TRUE;
			g_free(decomposition);
		    }
		}
		if (istypo &&
		  (pswit[VERBOSE_SWITCH] || !g_tree_lookup(qperiod,testword)))
		{
		    g_tree_insert(qperiod,g_strdup(testword),
		      GINT_TO_POINTER(1));
		    if (pswit[ECHO_SWITCH])
			g_print("\n%s\n",aline);
		    if (!pswit[OVERVIEW_SWITCH])
			g_print("    Line %ld column %ld - Extra period?\n",
			  linecnt,g_utf8_pointer_to_offset(aline,t)+1);
		    else
			cnt_punct++;
		}
		g_free(testword);
	    }
	    t=g_utf8_next_char(t);
	}
    }
}

/*
 * check_for_following_punctuation:
 *
 * Check for words usually not followed by punctuation.
 */
void check_for_following_punctuation(const char *aline)
{
    int i;
    const char *s,*wordstart;
    gunichar c;
    gchar *inword,*t;
    if (pswit[TYPO_SWITCH])
    {
	for (s=aline;*s;)
	{
	    wordstart=s;
	    t=getaword(&s);
	    if (!*t)
	    {
		g_free(t);
		continue;
	    }
	    inword=g_utf8_strdown(t,-1);
	    g_free(t);
	    for (i=0;*nocomma[i];i++)
		if (!strcmp(inword,nocomma[i]))
		{
		    c=g_utf8_get_char(s);
		    if (c==',' || c==';' || c==':')
		    {
			if (pswit[ECHO_SWITCH])
			    g_print("\n%s\n",aline);
			if (!pswit[OVERVIEW_SWITCH])
			    g_print("    Line %ld column %ld - "
			      "Query punctuation after %s?\n",
			      linecnt,g_utf8_pointer_to_offset(aline,s)+1,
			      inword);
			else
			    cnt_punct++;
		    }
		}
	    for (i=0;*noperiod[i];i++)
		if (!strcmp(inword,noperiod[i]))
		{
		    c=g_utf8_get_char(s);
		    if (c=='.' || c=='!')
		    {
			if (pswit[ECHO_SWITCH])
			    g_print("\n%s\n",aline);
			if (!pswit[OVERVIEW_SWITCH])
			    g_print("    Line %ld column %ld - "
			      "Query punctuation after %s?\n",
			      linecnt,g_utf8_pointer_to_offset(aline,s)+1,
			      inword);
			else
			    cnt_punct++;
		    }
		}
	    g_free(inword);
	}
    }
}

/*
 * check_for_typos:
 *
 * Check for commonly mistyped words,
 * and digits like 0 for O in a word.
 */
void check_for_typos(const char *aline,struct warnings *warnings)
{
    const char *s,*t,*nt,*wordstart;
    gchar *inword;
    gunichar *decomposition;
    gchar *testword;
    int i,vowel,consonant,*dupcnt;
    gboolean isdup,istypo,alower;
    gunichar c;
    long offset,len;
    gsize decomposition_len;
    for (s=aline;*s;)
    {
	wordstart=s;
	inword=getaword(&s);
	if (!*inword)
	{
	    g_free(inword);
	    continue; /* don't bother with empty lines */
	}
	if (mixdigit(inword))
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Query digit in %s\n",
		  linecnt,g_utf8_pointer_to_offset(aline,wordstart)+1,inword);
	    else
		cnt_word++;
	}
	/*
	 * Put the word through a series of tests for likely typos and OCR
	 * errors.
	 */
	if (pswit[TYPO_SWITCH] || pswit[USERTYPO_SWITCH])
	{
	    istypo=FALSE;
	    alower=FALSE;
	    for (t=inword;*t;t=g_utf8_next_char(t))
	    {
		c=g_utf8_get_char(t);
		nt=g_utf8_next_char(t);
		/* lowercase for testing */
		if (g_unichar_islower(c))
		    alower=TRUE;
		if (alower && (g_unichar_isupper(c) || g_unichar_istitle(c)))
		{
		    /*
		     * We have an uppercase mid-word. However, there are
		     * common cases:
		     *   Mac and Mc like McGill
		     *   French contractions like l'Abbe
		     */
		    offset=g_utf8_pointer_to_offset(inword,t);
		    if (offset==2 && c=='m' && g_utf8_get_char(nt)=='c' ||
		      offset==3 && c=='m' && g_utf8_get_char(nt)=='a' &&
		      g_utf8_get_char(g_utf8_next_char(nt))=='c' ||
		      offset>0 &&
		      g_utf8_get_char(g_utf8_prev_char(t))==CHAR_SQUOTE)
			; /* do nothing! */
		    else
			istypo=TRUE;
		}
	    }
	    testword=g_utf8_casefold(inword,-1);
	}
	if (pswit[TYPO_SWITCH])
	{
	    /*
	     * Check for certain unlikely two-letter combinations at word
	     * start and end.
	     */
	    len=g_utf8_strlen(testword,-1);
	    if (len>1)
	    {
		for (i=0;*nostart[i];i++)
		    if (g_str_has_prefix(testword,nostart[i]))
			istypo=TRUE;
		for (i=0;*noend[i];i++)
		    if (g_str_has_suffix(testword,noend[i]))
			istypo=TRUE;
	    }
	    /* ght is common, gbt never. Like that. */
	    if (strstr(testword,"cb"))
		istypo=TRUE;
	    if (strstr(testword,"gbt"))
		istypo=TRUE;
	    if (strstr(testword,"pbt"))
		istypo=TRUE;
	    if (strstr(testword,"tbs"))
		istypo=TRUE;
	    if (strstr(testword,"mrn"))
		istypo=TRUE;
	    if (strstr(testword,"ahle"))
		istypo=TRUE;
	    if (strstr(testword,"ihle"))
		istypo=TRUE;
	    /*
	     * "TBE" does happen - like HEARTBEAT - but uncommon.
	     * Also "TBI" - frostbite, outbid - but uncommon.
	     * Similarly "ii" like Hawaii, or Pompeii, and in Roman
	     * numerals, but "ii" is a common scanno.
	     */
	    if (strstr(testword,"tbi"))
		istypo=TRUE;
	    if (strstr(testword,"tbe"))
		istypo=TRUE;
	    if (strstr(testword,"ii"))
		istypo=TRUE;
	    /*
	     * Check for no vowels or no consonants.
	     * If none, flag a typo.
	     */
	    if (!istypo && len>1)
	    {
		vowel=consonant=0;
		for (t=testword;*t;t=g_utf8_next_char(t))
		{
		    c=g_utf8_get_char(t);
		    decomposition=
		      g_unicode_canonical_decomposition(c,&decomposition_len);
		    if (c=='y' || g_unichar_isdigit(c))
		    {
			/* Yah, this is loose. */
			vowel++;
			consonant++;
		    }
		    else if (g_utf8_strchr("aeiou",-1,decomposition[0]))
			vowel++;
		    else
			consonant++;
		    g_free(decomposition);
		}
		if (!vowel || !consonant)
		    istypo=TRUE;
	    }
	    /*
	     * Now exclude the word from being reported if it's in
	     * the okword list.
	     */
	    for (i=0;*okword[i];i++)
		if (!strcmp(testword,okword[i]))
		    istypo=FALSE;
	    /*
	     * What looks like a typo may be a Roman numeral.
	     * Exclude these.
	     */
	    if (istypo && isroman(testword))
		istypo=FALSE;
	    /* Check the manual list of typos. */
	    if (!istypo)
		for (i=0;*typo[i];i++)
		    if (!strcmp(testword,typo[i]))
			istypo=TRUE;
	    /*
	     * Check lowercase s, l, i and m - special cases.
	     *   "j" - often a semi-colon gone wrong.
	     *   "d" for a missing apostrophe - he d
	     *   "n" for "in"
	     */
	    if (!istypo && len==1 &&
	      g_utf8_strchr("slmijdn",-1,g_utf8_get_char(inword)))
		istypo=TRUE;
	    if (istypo)
	    {
		dupcnt=g_tree_lookup(qword,testword);
		if (dupcnt)
		{
		    (*dupcnt)++;
		    isdup=!pswit[VERBOSE_SWITCH];
		}
		else
		{
		    dupcnt=g_new0(int,1);
		    g_tree_insert(qword,g_strdup(testword),dupcnt);
		    isdup=FALSE;
		}
		if (!isdup)
		{
		    if (pswit[ECHO_SWITCH])
			g_print("\n%s\n",aline);
		    if (!pswit[OVERVIEW_SWITCH])
		    {
			g_print("    Line %ld column %ld - Query word %s",
			  linecnt,g_utf8_pointer_to_offset(aline,wordstart)+1,
			  inword);
			if (!pswit[VERBOSE_SWITCH])
			    g_print(" - not reporting duplicates");
			g_print("\n");
		    }
		    else
			cnt_word++;
		}
	    }
	}
	/* check the user's list of typos */
	if (!istypo && usertypo && g_tree_lookup(usertypo,testword))
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])  
		g_print("    Line %ld column %ld - Query possible scanno %s\n",
		  linecnt,g_utf8_pointer_to_offset(aline,wordstart)+2,inword);
	}
	if (pswit[TYPO_SWITCH] || pswit[USERTYPO_SWITCH])
	    g_free(testword);
	if (pswit[PARANOID_SWITCH] && warnings->digit)
	{
	    /* In paranoid mode, query all 0 and 1 standing alone. */
	    if (!strcmp(inword,"0") || !strcmp(inword,"1"))
	    {
		if (pswit[ECHO_SWITCH])
		    g_print("\n%s\n",aline);
		if (!pswit[OVERVIEW_SWITCH])
		    g_print("    Line %ld column %ld - Query standalone %s\n",
		      linecnt,g_utf8_pointer_to_offset(aline,wordstart)+2,
		      inword);
		else
		    cnt_word++;
	    }
	}
	g_free(inword);
    }
}

/*
 * check_for_misspaced_punctuation:
 *
 * Look for added or missing spaces around punctuation and quotes.
 * If there is a punctuation character like ! with no space on
 * either side, suspect a missing!space. If there are spaces on
 * both sides , assume a typo. If we see a double quote with no
 * space or punctuation on either side of it, assume unspaced
 * quotes "like"this.
 */
void check_for_misspaced_punctuation(const char *aline,
  struct parities *parities,gboolean isemptyline)
{
    gboolean isacro,isellipsis;
    const char *s;
    gunichar c,nc,pc,n2c;
    c=g_utf8_get_char(aline);
    nc=c?g_utf8_get_char(g_utf8_next_char(aline)):0;
    for (s=g_utf8_next_char(aline);nc;s=g_utf8_next_char(s))
    {
	pc=c;
	c=nc;
	nc=g_utf8_get_char(g_utf8_next_char(s));
	/* For each character in the line after the first. */
	if (g_utf8_strchr(".?!,;:_",-1,c))  /* if it's punctuation */
	{
	    /* we need to suppress warnings for acronyms like M.D. */
	    isacro=FALSE;
	    /* we need to suppress warnings for ellipsis . . . */
	    isellipsis=FALSE;
	    /*
	     * If there are letters on both sides of it or
	     * if it's strict punctuation followed by an alpha.
	     */
	    if (g_unichar_isalpha(nc) && (g_unichar_isalpha(pc) ||
	      g_utf8_strchr("?!,;:",-1,c)))
	    {
		if (c=='.')
		{
		    if (g_utf8_pointer_to_offset(aline,s)>2 &&
		      g_utf8_get_char(g_utf8_offset_to_pointer(s,-2))=='.')
			isacro=TRUE;
		    n2c=g_utf8_get_char(g_utf8_next_char(g_utf8_next_char(s)));
		    if (nc && n2c=='.')
			isacro=TRUE;
		}
		if (!isacro)
		{
		    if (pswit[ECHO_SWITCH])
			g_print("\n%s\n",aline);
		    if (!pswit[OVERVIEW_SWITCH])
			g_print("    Line %ld column %ld - Missing space?\n",
			  linecnt,g_utf8_pointer_to_offset(aline,s)+1);
		    else
			cnt_punct++;
		}
	    }
	    if (pc==CHAR_SPACE && (nc==CHAR_SPACE || !nc))
	    {
		/*
		 * If there are spaces on both sides,
		 * or space before and end of line.
		 */
		if (c=='.')
		{
		    if (g_utf8_pointer_to_offset(aline,s)>2 &&
		      g_utf8_get_char(g_utf8_offset_to_pointer(s,-2))=='.')
			isellipsis=TRUE;
		    n2c=g_utf8_get_char(g_utf8_next_char(g_utf8_next_char(s)));
		    if (nc && n2c=='.')
			isellipsis=TRUE;
		}
		if (!isemptyline && !isellipsis)
		{
		    if (pswit[ECHO_SWITCH])
			g_print("\n%s\n",aline);
		    if (!pswit[OVERVIEW_SWITCH])
			g_print("    Line %ld column %ld - "
			  "Spaced punctuation?\n",linecnt,
			  g_utf8_pointer_to_offset(aline,s)+1);
		    else
			cnt_punct++;
		}
	    }
	}
    }
    /* Split out the characters that CANNOT be preceded by space. */
    c=g_utf8_get_char(aline);
    nc=c?g_utf8_get_char(g_utf8_next_char(aline)):0;
    for (s=g_utf8_next_char(aline);nc;s=g_utf8_next_char(s))
    {
	pc=c;
	c=nc;
	nc=g_utf8_get_char(g_utf8_next_char(s));
	/* for each character in the line after the first */
	if (g_utf8_strchr("?!,;:",-1,c))
	{
	    /* if it's punctuation that _cannot_ have a space before it */
	    if (pc==CHAR_SPACE && !isemptyline && nc!=CHAR_SPACE)
	    {
		/*
		 * If nc DOES == space,
		 * it was already reported just above.
		 */
		if (pswit[ECHO_SWITCH])
		    g_print("\n%s\n",aline);
		if (!pswit[OVERVIEW_SWITCH])
		    g_print("    Line %ld column %ld - Spaced punctuation?\n",
		      linecnt,g_utf8_pointer_to_offset(aline,s)+1);
		else
		    cnt_punct++;
	    }
	}
    }
    /*
     * Special case " .X" where X is any alpha.
     * This plugs a hole in the acronym code above.
     * Inelegant, but maintainable.
     */
    c=g_utf8_get_char(aline);
    nc=c?g_utf8_get_char(g_utf8_next_char(aline)):0;
    for (s=g_utf8_next_char(aline);nc;s=g_utf8_next_char(s))
    {
	pc=c;
	c=nc;
	nc=g_utf8_get_char(g_utf8_next_char(s));
	/* for each character in the line after the first */
	if (c=='.')
	{
	    /* if it's a period */
	    if (pc==CHAR_SPACE && g_unichar_isalpha(nc))
	    {
		/*
		 * If the period follows a space and
		 * is followed by a letter.
		 */
		if (pswit[ECHO_SWITCH])
		    g_print("\n%s\n",aline);
		if (!pswit[OVERVIEW_SWITCH])
		    g_print("    Line %ld column %ld - Spaced punctuation?\n",
		      linecnt,g_utf8_pointer_to_offset(aline,s)+1);
		else
		    cnt_punct++;
	    }
	}
    }
    c=g_utf8_get_char(aline);
    nc=c?g_utf8_get_char(g_utf8_next_char(aline)):0;
    for (s=g_utf8_next_char(aline);nc;s=g_utf8_next_char(s))
    {
	pc=c;
	c=nc;
	nc=g_utf8_get_char(g_utf8_next_char(s));
	/* for each character in the line after the first */
	if (c==CHAR_DQUOTE)
	{
	    if (!g_utf8_strchr(" _-.'`,;:!/([{?}])",-1,pc) &&
	      !g_utf8_strchr(" _-.'`,;:!/([{?}])",-1,nc) && nc ||
	      !g_utf8_strchr(" _-([{'`",-1,pc) && g_unichar_isalpha(nc))
	    {
		if (pswit[ECHO_SWITCH])
		    g_print("\n%s\n",aline);
		if (!pswit[OVERVIEW_SWITCH])
		    g_print("    Line %ld column %ld - Unspaced quotes?\n",
		      linecnt,g_utf8_pointer_to_offset(aline,s)+1);
		else
		    cnt_punct++;
	    }
	}
    }
    /* Check parity of quotes. */
    nc=g_utf8_get_char(aline);
    for (s=aline;*s;s=g_utf8_next_char(s))
    {
	c=nc;
	nc=g_utf8_get_char(g_utf8_next_char(s));
	if (c==CHAR_DQUOTE)
	{
	    parities->dquote=!parities->dquote;
	    if (!parities->dquote)
	    {
		/* parity even */
		if (!g_utf8_strchr("_-.'`/,;:!?)]} ",-1,nc))
		{
		    if (pswit[ECHO_SWITCH])
			g_print("\n%s\n",aline);
		    if (!pswit[OVERVIEW_SWITCH])
			g_print("    Line %ld column %ld - "
			  "Wrongspaced quotes?\n",
			  linecnt,g_utf8_pointer_to_offset(aline,s)+1);
		    else
			cnt_punct++;
		}
	    }
	    else
	    {
		/* parity odd */
		if (!g_unichar_isalpha(nc) && !isdigit(nc) &&
		  !g_utf8_strchr("_-/.'`([{$",-1,nc) || !nc)
		{
		    if (pswit[ECHO_SWITCH])
			g_print("\n%s\n",aline);
		    if (!pswit[OVERVIEW_SWITCH])
			g_print("    Line %ld column %ld - "
			  "Wrongspaced quotes?\n",
			  linecnt,g_utf8_pointer_to_offset(aline,s)+1);
		    else
			cnt_punct++;
		}
	    }
	}
    }
    if (g_utf8_get_char(aline)==CHAR_DQUOTE)
    {
	if (g_utf8_strchr(",;:!?)]} ",-1,
	  g_utf8_get_char(g_utf8_next_char(aline))))
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column 1 - Wrongspaced quotes?\n",
		  linecnt);
	    else
		cnt_punct++;
	}
    }
    if (pswit[SQUOTE_SWITCH])
    {
	nc=g_utf8_get_char(aline);
	for (s=aline;*s;s=g_utf8_next_char(s))
	{
	    c=nc;
	    nc=g_utf8_get_char(g_utf8_next_char(s));
	    if ((c==CHAR_SQUOTE || c==CHAR_OPEN_SQUOTE) && (s==aline ||
	      s>aline &&
	      !g_unichar_isalpha(g_utf8_get_char(g_utf8_prev_char(s))) ||
	      !g_unichar_isalpha(nc)))
	    {
		parities->squote=!parities->squote;
		if (!parities->squote)
		{
		    /* parity even */
		    if (!g_utf8_strchr("_-.'`/\",;:!?)]} ",-1,nc))
		    {
			if (pswit[ECHO_SWITCH])
			    g_print("\n%s\n",aline);
			if (!pswit[OVERVIEW_SWITCH])
			    g_print("    Line %ld column %ld - "
			      "Wrongspaced singlequotes?\n",
			      linecnt,g_utf8_pointer_to_offset(aline,s)+1);
			else
			    cnt_punct++;
		    }
		}
		else
		{
		    /* parity odd */
		    if (!g_unichar_isalpha(nc) && !isdigit(nc) &&
		      !g_utf8_strchr("_-/\".'`",-1,nc) || !nc)
		    {
			if (pswit[ECHO_SWITCH])
			    g_print("\n%s\n",aline);
			if (!pswit[OVERVIEW_SWITCH])
			    g_print("    Line %ld column %ld - "
			      "Wrongspaced singlequotes?\n",
			      linecnt,g_utf8_pointer_to_offset(aline,s)+1);
			else
			    cnt_punct++;
		    }
		}
	    }
	}
    }
}

/*
 * check_for_double_punctuation:
 *
 * Look for double punctuation like ,. or ,,
 * Thanks to DW for the suggestion!
 * In books with references, ".," and ".;" are common
 * e.g. "etc., etc.," and vol. 1.; vol 3.;
 * OTOH, from my initial tests, there are also fairly
 * common errors. What to do? Make these cases paranoid?
 * ".," is the most common, so warnings->dotcomma is used
 * to suppress detailed reporting if it occurs often.
 */
void check_for_double_punctuation(const char *aline,struct warnings *warnings)
{
    const char *s;
    gunichar c,nc;
    nc=g_utf8_get_char(aline);
    for (s=aline;*s;s=g_utf8_next_char(s))
    {
	c=nc;
	nc=g_utf8_get_char(g_utf8_next_char(s));
	/* for each punctuation character in the line */
	if (c && nc && g_utf8_strchr(".?!,;:",-1,c) &&
	  g_utf8_strchr(".?!,;:",-1,nc))
	{
	    /* followed by punctuation, it's a query, unless . . . */
	    if (c==nc && (c=='.' || c=='?' || c=='!') ||
	      !warnings->dotcomma && c=='.' && nc==',' ||
	      warnings->isFrench && g_str_has_prefix(s,",...") ||
	      warnings->isFrench && g_str_has_prefix(s,"...,") ||
	      warnings->isFrench && g_str_has_prefix(s,";...") ||
	      warnings->isFrench && g_str_has_prefix(s,"...;") ||
	      warnings->isFrench && g_str_has_prefix(s,":...") ||
	      warnings->isFrench && g_str_has_prefix(s,"...:") ||
	      warnings->isFrench && g_str_has_prefix(s,"!...") ||
	      warnings->isFrench && g_str_has_prefix(s,"...!") ||
	      warnings->isFrench && g_str_has_prefix(s,"?...") ||
	      warnings->isFrench && g_str_has_prefix(s,"...?"))
	    {
		if (warnings->isFrench && g_str_has_prefix(s,",...") ||
		  warnings->isFrench && g_str_has_prefix(s,"...,") ||
		  warnings->isFrench && g_str_has_prefix(s,";...") ||
		  warnings->isFrench && g_str_has_prefix(s,"...;") ||
		  warnings->isFrench && g_str_has_prefix(s,":...") ||
		  warnings->isFrench && g_str_has_prefix(s,"...:") ||
		  warnings->isFrench && g_str_has_prefix(s,"!...") ||
		  warnings->isFrench && g_str_has_prefix(s,"...!") ||
		  warnings->isFrench && g_str_has_prefix(s,"?...") ||
		  warnings->isFrench && g_str_has_prefix(s,"...?"))
		{
		    s+=4;
		    nc=g_utf8_get_char(g_utf8_next_char(s));
		}
		; /* do nothing for .. !! and ?? which can be legit */
	    }
	    else
	    {
		if (pswit[ECHO_SWITCH])
		    g_print("\n%s\n",aline);
		if (!pswit[OVERVIEW_SWITCH])
		    g_print("    Line %ld column %ld - Double punctuation?\n",
		      linecnt,g_utf8_pointer_to_offset(aline,s)+1);
		else
		    cnt_punct++;
	    }
	}
    }
}

/*
 * check_for_spaced_quotes:
 */
void check_for_spaced_quotes(const char *aline)
{
    const char *s,*t;
    s=aline;
    while ((t=strstr(s," \" ")))
    {
	if (pswit[ECHO_SWITCH])
	    g_print("\n%s\n",aline);
	if (!pswit[OVERVIEW_SWITCH])
	    g_print("    Line %ld column %ld - Spaced doublequote?\n",
	      linecnt,g_utf8_pointer_to_offset(aline,t)+1);
	else
	    cnt_punct++;
	s=g_utf8_next_char(g_utf8_next_char(t));
    }
    s=aline;
    while ((t=strstr(s," ' ")))
    {
	if (pswit[ECHO_SWITCH])
	    g_print("\n%s\n",aline);
	if (!pswit[OVERVIEW_SWITCH])
	    g_print("    Line %ld column %ld - Spaced singlequote?\n",
	      linecnt,g_utf8_pointer_to_offset(aline,t)+1);
	else
	    cnt_punct++;
	s=g_utf8_next_char(g_utf8_next_char(t));
    }
    s=aline;
    while ((t=strstr(s," ` ")))
    {
	if (pswit[ECHO_SWITCH])
	    g_print("\n%s\n",aline);
	if (!pswit[OVERVIEW_SWITCH])
	    g_print("    Line %ld column %ld - Spaced singlequote?\n",
	      linecnt,g_utf8_pointer_to_offset(aline,t)+1);
	else
	    cnt_punct++;
	s=g_utf8_next_char(g_utf8_next_char(t));
    }
}

/*
 * check_for_miscased_genative:
 *
 * Check special case of 'S instead of 's at end of word.
 */
void check_for_miscased_genative(const char *aline)
{
    const char *s;
    gunichar c,nc,pc;
    if (!*aline)
	return;
    c=g_utf8_get_char(aline);
    nc=c?g_utf8_get_char(g_utf8_next_char(aline)):0;
    for (s=g_utf8_next_char(aline);nc;s=g_utf8_next_char(s))
    {
	pc=c;
	c=nc;
	nc=g_utf8_get_char(g_utf8_next_char(s));
	if (c==CHAR_SQUOTE && nc=='S' && g_unichar_islower(pc))
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Capital \"S\"?\n",
		  linecnt,g_utf8_pointer_to_offset(aline,s)+2);
	    else
		cnt_punct++;
	}
    }
}

/*
 * check_end_of_line:
 *
 * Now check special cases - start and end of line -
 * for single and double quotes. Start is sometimes [sic]
 * but better to query it anyway.
 * While we're here, check for dash at end of line.
 */
void check_end_of_line(const char *aline,struct warnings *warnings)
{
    int lbytes;
    const char *s;
    gunichar c1,c2;
    lbytes=strlen(aline);
    if (g_utf8_strlen(aline,lbytes)>1)
    {
	s=g_utf8_prev_char(aline+lbytes);
	c1=g_utf8_get_char(s);
	c2=g_utf8_get_char(g_utf8_prev_char(s));
	if ((c1==CHAR_DQUOTE || c1==CHAR_SQUOTE || c1==CHAR_OPEN_SQUOTE) &&
	  c2==CHAR_SPACE)
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Spaced quote?\n",linecnt,
		  g_utf8_strlen(aline,lbytes));
	    else
		cnt_punct++;
	}
	c1=g_utf8_get_char(aline);
	c2=g_utf8_get_char(g_utf8_next_char(aline));
	if ((c1==CHAR_SQUOTE || c1==CHAR_OPEN_SQUOTE) && c2==CHAR_SPACE)
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column 1 - Spaced quote?\n",linecnt);
	    else
		cnt_punct++;
	}
	/*
	 * Dash at end of line may well be legit - paranoid mode only
	 * and don't report em-dash at line-end.
	 */
	if (pswit[PARANOID_SWITCH] && warnings->hyphen)
	{
	    for (s=g_utf8_prev_char(aline+lbytes);
	      s>aline && g_utf8_get_char(s)<=CHAR_SPACE;s=g_utf8_prev_char(s))
		;
	    if (g_utf8_get_char(s)=='-' &&
	      g_utf8_get_char(g_utf8_prev_char(s))!='-')
	    {
		if (pswit[ECHO_SWITCH])
		    g_print("\n%s\n",aline);
		if (!pswit[OVERVIEW_SWITCH])
		    g_print("    Line %ld column %ld - "
		      "Hyphen at end of line?\n",
		      linecnt,g_utf8_pointer_to_offset(aline,s));
	    }
	}
    }
}

/*
 * check_for_unspaced_bracket:
 *
 * Brackets are often unspaced, but shouldn't be surrounded by alpha.
 * If so, suspect a scanno like "a]most".
 */
void check_for_unspaced_bracket(const char *aline)
{
    const char *s;
    gunichar c,nc,pc;
    c=g_utf8_get_char(aline);
    nc=c?g_utf8_get_char(g_utf8_next_char(aline)):0;
    for (s=g_utf8_next_char(aline);nc;s=g_utf8_next_char(s))
    {
	pc=c;
	c=nc;
	nc=g_utf8_get_char(g_utf8_next_char(s));
	if (!nc)
	    break;
	/* for each bracket character in the line except 1st & last */
	if (g_utf8_strchr("{[()]}",-1,c) &&
	  g_unichar_isalpha(pc) && g_unichar_isalpha(nc))
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - Unspaced bracket?\n",
		  linecnt,g_utf8_pointer_to_offset(aline,s));
	    else
		cnt_punct++;
	}
    }
}

/*
 * check_for_unpunctuated_endquote:
 */
void check_for_unpunctuated_endquote(const char *aline)
{
    const char *s;
    gunichar c,nc,pc;
    c=g_utf8_get_char(aline);
    nc=c?g_utf8_get_char(g_utf8_next_char(aline)):0;
    for (s=g_utf8_next_char(aline);nc;s=g_utf8_next_char(s))
    {
	pc=c;
	c=nc;
	nc=g_utf8_get_char(g_utf8_next_char(s));
	/* for each character in the line except 1st */
	if (c==CHAR_DQUOTE && isalpha(pc))
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column %ld - "
		  "endquote missing punctuation?\n",
		  linecnt,g_utf8_pointer_to_offset(aline,s));
	    else
		cnt_punct++;
	}
    }
}

/*
 * check_for_html_tag:
 *
 * Check for <HTML TAG>.
 *
 * If there is a < in the line, followed at some point
 * by a > then we suspect HTML.
 */
void check_for_html_tag(const char *aline)
{
    const char *open,*close;
    gchar *tag;
    open=strchr(aline,'<');
    if (open)
    {
	close=strchr(g_utf8_next_char(open),'>');
	if (close)
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
	    {
		tag=g_strndup(open,close-open+1);
		g_print("    Line %ld column %ld - HTML Tag? %s \n",
		  linecnt,g_utf8_pointer_to_offset(aline,open)+1,tag);
		g_free(tag);
	    }
	    else
		cnt_html++;
	}
    }
}

/*
 * check_for_html_entity:
 *
 * Check for &symbol; HTML.
 *
 * If there is a & in the line, followed at
 * some point by a ; then we suspect HTML.
 */
void check_for_html_entity(const char *aline)
{
    const char *s,*amp,*scolon;
    gchar *entity;
    amp=strchr(aline,'&');
    if (amp)
    {
	scolon=strchr(amp,';');
	if (scolon)
	{
	    for (s=amp;s<scolon;s=g_utf8_next_char(s))   
		if (g_utf8_get_char(s)==CHAR_SPACE)
		    break;		/* Don't report "Jones & Son;" */
	    if (s>=scolon)
	    {
		if (pswit[ECHO_SWITCH])
		    g_print("\n%s\n",aline);
		if (!pswit[OVERVIEW_SWITCH])
		{
		    entity=g_strndup(amp,scolon-amp+1);
		    g_print("    Line %ld column %d - HTML symbol? %s \n",
		      linecnt,(int)(amp-aline)+1,entity);
		    g_free(entity);
		}
		else
		    cnt_html++;
	    }
	}
    }
}

/*
 * print_pending:
 *
 * If we are in a state of unbalanced quotes, and this line
 * doesn't begin with a quote, output the stored error message.
 * If the -P switch was used, print the warning even if the
 * new para starts with quotes.
 */
void print_pending(const char *aline,const char *parastart,
  struct pending *pending)
{
    const char *s;
    gunichar c;
    s=aline;
    while (*s==' ')
	s++;
    c=g_utf8_get_char(s);
    if (pending->dquote)
    {
	if (c!=CHAR_DQUOTE || pswit[QPARA_SWITCH])
	{
	    if (!pswit[OVERVIEW_SWITCH])
	    {
		if (pswit[ECHO_SWITCH])
		    g_print("\n%s\n",parastart);
		g_print("%s\n",pending->dquote);
	    }
	    else
		cnt_dquot++;
	}
	g_free(pending->dquote);
	pending->dquote=NULL;
    }
    if (pending->squote)
    {
	if (c!=CHAR_SQUOTE && c!=CHAR_OPEN_SQUOTE || pswit[QPARA_SWITCH] ||
	  pending->squot)
	{
	    if (!pswit[OVERVIEW_SWITCH])
	    {
		if (pswit[ECHO_SWITCH])
		    g_print("\n%s\n",parastart);
		g_print("%s\n",pending->squote);
	    }
	    else
		cnt_squot++;
	}
	g_free(pending->squote);
	pending->squote=NULL;
    }
    if (pending->rbrack)
    {
	if (!pswit[OVERVIEW_SWITCH])
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",parastart);
	    g_print("%s\n",pending->rbrack);
	}
	else
	    cnt_brack++;
	g_free(pending->rbrack);
	pending->rbrack=NULL;
    }
    if (pending->sbrack)
    {
	if (!pswit[OVERVIEW_SWITCH])
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",parastart);
	    g_print("%s\n",pending->sbrack);
	}
	else
	    cnt_brack++;
	g_free(pending->sbrack);
	pending->sbrack=NULL;
    }
    if (pending->cbrack)
    {
	if (!pswit[OVERVIEW_SWITCH])
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",parastart);
	    g_print("%s\n",pending->cbrack);
	}
	else
	    cnt_brack++;
	g_free(pending->cbrack);
	pending->cbrack=NULL;
    }
    if (pending->unders)
    {
	if (!pswit[OVERVIEW_SWITCH])
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",parastart);
	    g_print("%s\n",pending->unders);
	}
	else
	    cnt_brack++;
	g_free(pending->unders);
	pending->unders=NULL;
    }
}

/*
 * check_for_mismatched_quotes:
 *
 * At end of paragraph, check for mismatched quotes.
 *
 * We don't want to report an error immediately, since it is a
 * common convention to omit the quotes at end of paragraph if
 * the next paragraph is a continuation of the same speaker.
 * Where this is the case, the next para should begin with a
 * quote, so we store the warning message and only display it
 * at the top of the next iteration if the new para doesn't
 * start with a quote.
 * The -p switch overrides this default, and warns of unclosed
 * quotes on _every_ paragraph, whether the next begins with a
 * quote or not.
 */
void check_for_mismatched_quotes(const struct counters *counters,
  struct pending *pending)
{
    if (counters->quot%2)
	pending->dquote=
	  g_strdup_printf("    Line %ld - Mismatched quotes",linecnt);
    if (pswit[SQUOTE_SWITCH] && counters->open_single_quote &&
      counters->open_single_quote!=counters->close_single_quote)
	pending->squote=
	  g_strdup_printf("    Line %ld - Mismatched singlequotes?",linecnt);
    if (pswit[SQUOTE_SWITCH] && counters->open_single_quote &&
      counters->open_single_quote!=counters->close_single_quote &&
      counters->open_single_quote!=counters->close_single_quote+1)
	/*
	 * Flag it to be noted regardless of the
	 * first char of the next para.
	 */
	pending->squot=1;
    if (counters->r_brack)
	pending->rbrack=
	  g_strdup_printf("    Line %ld - Mismatched round brackets?",linecnt);
    if (counters->s_brack)
	pending->sbrack=
	  g_strdup_printf("    Line %ld - Mismatched square brackets?",linecnt);
    if (counters->c_brack)
	pending->cbrack=
	  g_strdup_printf("    Line %ld - Mismatched curly brackets?",linecnt);
    if (counters->c_unders%2)
	pending->unders=
	  g_strdup_printf("    Line %ld - Mismatched underscores?",linecnt);
}

/*
 * check_for_omitted_punctuation:
 *
 * Check for omitted punctuation at end of paragraph by working back
 * through prevline. DW.
 * Need to check this only for "normal" paras.
 * So what is a "normal" para?
 *    Not normal if one-liner (chapter headings, etc.)
 *    Not normal if doesn't contain at least one locase letter
 *    Not normal if starts with space
 */
void check_for_omitted_punctuation(const char *prevline,
  struct line_properties *last,int start_para_line)
{
    gboolean letter_on_line=FALSE;
    const char *s;
    for (s=prevline;*s;s=g_utf8_next_char(s))
	if (g_unichar_isalpha(g_utf8_get_char(s)))
	{
	    letter_on_line=TRUE;
	    break;
	}
    /*
     * This next "if" is a problem.
     * If we say "start_para_line <= linecnt - 1", that includes
     * one-line "paragraphs" like chapter heads. Lotsa false positives.
     * If we say "start_para_line < linecnt - 1" it doesn't, but then it
     * misses genuine one-line paragraphs.
     */
    if (letter_on_line && last->blen>2 && start_para_line<linecnt-1 &&
      g_utf8_get_char(prevline)>CHAR_SPACE)
    {
	for (s=g_utf8_prev_char(prevline+strlen(prevline));
	  (g_utf8_get_char(s)==CHAR_DQUOTE ||
	  g_utf8_get_char(s)==CHAR_SQUOTE) &&
	  g_utf8_get_char(s)>CHAR_SPACE && s>prevline;
	  s=g_utf8_prev_char(s))
	    ;
	for (;s>prevline;s=g_utf8_prev_char(s))
	{
	    if (g_unichar_isalpha(g_utf8_get_char(s)))
	    {
		if (pswit[ECHO_SWITCH])
		    g_print("\n%s\n",prevline);
		if (!pswit[OVERVIEW_SWITCH])
		    g_print("    Line %ld column %ld - "
		      "No punctuation at para end?\n",
		      linecnt-1,g_utf8_strlen(prevline,-1));
		else
		    cnt_punct++;
		break;
	    }
	    if (g_utf8_strchr("-.:!([{?}])",-1,g_utf8_get_char(s)))
		break;
	}
    }
}

gboolean report_duplicate_queries(gpointer key,gpointer value,gpointer data)
{
    const char *word=key;
    int *dupcnt=value;
    if (*dupcnt)
	g_print("\nNote: Queried word %s was duplicated %d times\n",
	  word,*dupcnt);
    return FALSE;
}

void print_as_windows_1252(const char *string)
{
    gsize inbytes,outbytes;
    gchar *buf,*bp;
    static GIConv converter=(GIConv)-1;
    if (!string)
    {
	if (converter!=(GIConv)-1)
	    g_iconv_close(converter);
	converter=(GIConv)-1;
	return;
    }
    if (converter==(GIConv)-1)
	converter=g_iconv_open("WINDOWS-1252","UTF-8");
    if (converter!=(GIConv)-1)
    {
	inbytes=outbytes=strlen(string);
	bp=buf=g_malloc(outbytes+1);
	g_iconv(converter,(char **)&string,&inbytes,&bp,&outbytes);
	*bp='\0';
	fputs(buf,stdout);
	g_free(buf);
    }
    else
	fputs(string,stdout);
}

void print_as_utf_8(const char *string)
{
    fputs(string,stdout);
}

/*
 * procfile:
 *
 * Process one file.
 */
void procfile(const char *filename)
{
    const char *s;
    gchar *parastart=NULL;	/* first line of current para */
    gchar *etext,*aline;
    gchar *etext_ptr;
    GError *err=NULL;
    struct first_pass_results *first_pass_results;
    struct warnings *warnings;
    struct counters counters={0};
    struct line_properties last={0};
    struct parities parities={0};
    struct pending pending={0};
    gboolean isemptyline;
    long start_para_line=0;
    gboolean isnewpara=FALSE,enddash=FALSE;
    last.start=CHAR_SPACE;
    linecnt=checked_linecnt=0;
    etext=read_etext(filename,&err);
    if (!etext)
    {
	if (pswit[STDOUT_SWITCH])
	    fprintf(stdout,"bookloupe: %s: %s\n",filename,err->message);
	else
	    fprintf(stderr,"bookloupe: %s: %s\n",filename,err->message);
	exit(1);
    }
    g_print("\n\nFile: %s\n\n",filename);
    first_pass_results=first_pass(etext);
    warnings=report_first_pass(first_pass_results);
    qword=g_tree_new_full((GCompareDataFunc)strcmp,NULL,g_free,g_free);
    qperiod=g_tree_new_full((GCompareDataFunc)strcmp,NULL,g_free,NULL);
    /*
     * Here we go with the main pass. Hold onto yer hat!
     */
    linecnt=0;
    etext_ptr=etext;
    while ((aline=flgets(&etext_ptr,linecnt+1)))
    {
	linecnt++;
	if (linecnt==1)
	    isnewpara=TRUE;
	if (pswit[DP_SWITCH] && g_str_has_prefix(aline,"-----File: "))
	    continue;    // skip DP page separators completely
	if (linecnt<first_pass_results->firstline ||
	  (first_pass_results->footerline>0 &&
	  linecnt>first_pass_results->footerline))
	{
	    if (pswit[HEADER_SWITCH])
	    {
		if (g_str_has_prefix(aline,"Title:"))
		    g_print("    %s\n",aline);
		if (g_str_has_prefix(aline,"Author:"))
		    g_print("    %s\n",aline);
		if (g_str_has_prefix(aline,"Release Date:"))
		    g_print("    %s\n",aline);
		if (g_str_has_prefix(aline,"Edition:"))
		    g_print("    %s\n\n",aline);
	    }
	    continue;		/* skip through the header */
	}
	checked_linecnt++;
	print_pending(aline,parastart,&pending);
	memset(&pending,0,sizeof(pending));
	isemptyline=analyse_quotes(aline,&counters);
	if (isnewpara && !isemptyline)
	{
	    /* This line is the start of a new paragraph. */
	    start_para_line=linecnt;
	    /* Capture its first line in case we want to report it later. */
	    g_free(parastart);
	    parastart=g_strdup(aline);
	    memset(&parities,0,sizeof(parities));  /* restart the quote count */
	    s=aline;
	    while (*s && !g_unichar_isalpha(g_utf8_get_char(s)) &&
	      !g_unichar_isdigit(g_utf8_get_char(s)))
		s=g_utf8_next_char(s);
	    if (g_unichar_islower(g_utf8_get_char(s)))
	    {
		/* and its first letter is lowercase */
		if (pswit[ECHO_SWITCH])
		    g_print("\n%s\n",aline);
		if (!pswit[OVERVIEW_SWITCH])
		    g_print("    Line %ld column %ld - "
		      "Paragraph starts with lower-case\n",
		      linecnt,g_utf8_pointer_to_offset(aline,s)+1);
		else
		    cnt_punct++;
	    }
	    isnewpara=FALSE; /* Signal the end of new para processing. */
	}
	/* Check for an em-dash broken at line end. */
	if (enddash && g_utf8_get_char(aline)=='-')
	{
	    if (pswit[ECHO_SWITCH])
		g_print("\n%s\n",aline);
	    if (!pswit[OVERVIEW_SWITCH])
		g_print("    Line %ld column 1 - Broken em-dash?\n",linecnt);
	    else
		cnt_punct++;
	}
	enddash=FALSE;
	for (s=g_utf8_prev_char(aline+strlen(aline));
	  g_utf8_get_char(s)==' ' && s>aline;s=g_utf8_prev_char(s))
	    ;
	if (s>=aline && g_utf8_get_char(s)=='-')
	    enddash=TRUE;
	check_for_control_characters(aline);
	if (warnings->bin)
	    check_for_odd_characters(aline,warnings,isemptyline);
	if (warnings->longline)
	    check_for_long_line(aline);
	if (warnings->shortline)
	    check_for_short_line(aline,&last);
	last.blen=last.len;
	last.len=g_utf8_strlen(aline,-1);
	last.start=g_utf8_get_char(aline);
	check_for_starting_punctuation(aline);
	if (warnings->dash)
	{
	    check_for_spaced_emdash(aline);
	    check_for_spaced_dash(aline);
	}
	check_for_unmarked_paragraphs(aline);
	check_for_jeebies(aline);
	check_for_mta_from(aline);
	check_for_orphan_character(aline);
	check_for_pling_scanno(aline);
	check_for_extra_period(aline,warnings);
	check_for_following_punctuation(aline);
	check_for_typos(aline,warnings);
	check_for_misspaced_punctuation(aline,&parities,isemptyline);
	check_for_double_punctuation(aline,warnings);
	check_for_spaced_quotes(aline);
	check_for_miscased_genative(aline);
	check_end_of_line(aline,warnings);
	check_for_unspaced_bracket(aline);
	if (warnings->endquote)
	    check_for_unpunctuated_endquote(aline);
	check_for_html_tag(aline);
	check_for_html_entity(aline);
	if (isemptyline)
	{
	    check_for_mismatched_quotes(&counters,&pending);
	    memset(&counters,0,sizeof(counters));
	    /* let the next iteration know that it's starting a new para */
	    isnewpara=TRUE;
	    if (prevline)
		check_for_omitted_punctuation(prevline,&last,start_para_line);
	}
	g_free(prevline);
	prevline=g_strdup(aline);
    }
    if (prevline)
    {
	g_free(prevline);
	prevline=NULL;
    }
    g_free(parastart);
    g_free(prevline);
    g_free(etext);
    if (!pswit[OVERVIEW_SWITCH] && !pswit[VERBOSE_SWITCH])
	g_tree_foreach(qword,report_duplicate_queries,NULL);
    g_tree_unref(qword);
    g_tree_unref(qperiod);
    g_set_print_handler(NULL);
    print_as_windows_1252(NULL);
    if (pswit[MARKUP_SWITCH])  
	loseentities(NULL);
}

/*
 * flgets:
 *
 * Get one line from the input text, checking for
 * the existence of exactly one CR/LF line-end per line.
 *
 * Returns: a pointer to the line.
 */
char *flgets(char **etext,long lcnt)
{
    gunichar c;
    gboolean isCR=FALSE;
    char *theline=*etext;
    char *eos=theline;
    gchar *s;
    for (;;)
    {
	c=g_utf8_get_char(*etext);
	*etext=g_utf8_next_char(*etext);
	if (!c)
	    return NULL;
	/* either way, it's end of line */
	if (c=='\n')
	{
	    if (isCR)
		break;
	    else
	    {
		/* Error - a LF without a preceding CR */
		if (pswit[LINE_END_SWITCH])
		{
		    if (pswit[ECHO_SWITCH])
		    {
			s=g_strndup(theline,eos-theline);
			g_print("\n%s\n",s);
			g_free(s);
		    }
		    if (!pswit[OVERVIEW_SWITCH])
			g_print("    Line %ld - No CR?\n",lcnt);
		    else
			cnt_lineend++;
		}
		break;
	    }
	}
	if (c=='\r')
	{
	    if (isCR)
	    {
		/* Error - two successive CRs */
		if (pswit[LINE_END_SWITCH])
		{
		    if (pswit[ECHO_SWITCH])
		    {
			s=g_strndup(theline,eos-theline);
			g_print("\n%s\n",s);
			g_free(s);
		    }
		    if (!pswit[OVERVIEW_SWITCH])
			g_print("    Line %ld - Two successive CRs?\n",lcnt);
		    else
			cnt_lineend++;
		}
	    }
	    isCR=TRUE;
	}
	else
	{
	    if (pswit[LINE_END_SWITCH] && isCR)
	    {
		if (pswit[ECHO_SWITCH])
		{
		    s=g_strndup(theline,eos-theline);
		    g_print("\n%s\n",s);
		    g_free(s);
		}
		if (!pswit[OVERVIEW_SWITCH])
		    g_print("    Line %ld column %ld - CR without LF?\n",
		      lcnt,g_utf8_pointer_to_offset(theline,eos)+1);
		else
		    cnt_lineend++;
		*eos=' ';
	    }
	    isCR=FALSE;
	    eos=g_utf8_next_char(eos);
	}
    }
    *eos='\0';
    if (pswit[MARKUP_SWITCH])  
	postprocess_for_HTML(theline);
    if (pswit[DP_SWITCH])  
	postprocess_for_DP(theline);
    return theline;
}

/*
 * mixdigit:
 *
 * Takes a "word" as a parameter, and checks whether it
 * contains a mixture of alpha and digits. Generally, this is an
 * error, but may not be for cases like 4th or L5 12s. 3d.
 *
 * Returns: TRUE iff an is error found.
 */
gboolean mixdigit(const char *checkword)
{
    gboolean wehaveadigit,wehavealetter,query;
    const char *s,*nondigit;
    wehaveadigit=wehavealetter=query=FALSE;
    for (s=checkword;*s;s=g_utf8_next_char(s))
	if (g_unichar_isalpha(g_utf8_get_char(s)))
	    wehavealetter=TRUE;
	else if (g_unichar_isdigit(g_utf8_get_char(s)))
	    wehaveadigit=TRUE;
    if (wehaveadigit && wehavealetter)
    {
	/* Now exclude common legit cases, like "21st" and "12l. 3s. 11d." */
	query=TRUE;
	for (nondigit=checkword;g_unichar_isdigit(g_utf8_get_char(nondigit));
	  nondigit=g_utf8_next_char(nondigit))
	    ;
	/* digits, ending in st, rd, nd, th of either case */
	if (!g_ascii_strcasecmp(nondigit,"st") ||
	  !g_ascii_strcasecmp(nondigit,"rd") ||
	  !g_ascii_strcasecmp(nondigit,"nd") ||
	  !g_ascii_strcasecmp(nondigit,"th"))
	    query=FALSE;
	if (!g_ascii_strcasecmp(nondigit,"sts") ||
	  !g_ascii_strcasecmp(nondigit,"rds") ||
	  !g_ascii_strcasecmp(nondigit,"nds") ||
	  !g_ascii_strcasecmp(nondigit,"ths"))
	    query=FALSE;
	if (!g_ascii_strcasecmp(nondigit,"stly") ||
	  !g_ascii_strcasecmp(nondigit,"rdly") ||
	  !g_ascii_strcasecmp(nondigit,"ndly") ||
	  !g_ascii_strcasecmp(nondigit,"thly"))
	    query=FALSE;
	/* digits, ending in l, L, s or d */
	if (!g_ascii_strcasecmp(nondigit,"l") || !strcmp(nondigit,"s") ||
	  !strcmp(nondigit,"d"))
	    query=FALSE;
	/*
	 * L at the start of a number, representing Britsh pounds, like L500.
	 * This is cute. We know the current word is mixed digit. If the first
	 * letter is L, there must be at least one digit following. If both
	 * digits and letters follow, we have a genuine error, else we have a
	 * capital L followed by digits, and we accept that as a non-error.
	 */
	if (g_utf8_get_char(checkword)=='L' &&
	  !mixdigit(g_utf8_next_char(checkword)))
	    query=FALSE;
    }
    return query;
}

/*
 * getaword:
 *
 * Extracts the first/next "word" from the line, and returns it.
 * A word is defined as one English word unit--or at least that's the aim.
 * "ptr" is advanced to the position in the line where we will start
 * looking for the next word.
 *
 * Returns: A newly-allocated string.
 */
gchar *getaword(const char **ptr)
{
    const char *s,*t;
    GString *word;
    gunichar c,pc;
    word=g_string_new(NULL);
    for (;!g_unichar_isdigit(g_utf8_get_char(*ptr)) &&
      !g_unichar_isalpha(g_utf8_get_char(*ptr)) &&
      **ptr;*ptr=g_utf8_next_char(*ptr))
	;
    /*
     * Use a look-ahead to handle exceptions for numbers like 1,000 and 1.35.
     * Especially yucky is the case of L1,000
     * This section looks for a pattern of characters including a digit
     * followed by a comma or period followed by one or more digits.
     * If found, it returns this whole pattern as a word; otherwise we discard
     * the results and resume our normal programming.
     */
    s=*ptr;
    for (;g_unichar_isdigit(g_utf8_get_char(s)) ||
      g_unichar_isalpha(g_utf8_get_char(s)) ||
      g_utf8_get_char(s)==',' || g_utf8_get_char(s)=='.';s=g_utf8_next_char(s))
	g_string_append_unichar(word,g_utf8_get_char(s));
    if (word->len)
    {
	for (t=g_utf8_next_char(word->str);*t;t=g_utf8_next_char(t))
	{
	    c=g_utf8_get_char(t);
	    pc=g_utf8_get_char(g_utf8_prev_char(t));
	    if ((c=='.' || c==',') && g_unichar_isdigit(pc))
	    {
		*ptr=s;
		return g_string_free(word,FALSE);
	    }
	}
    }
    /* we didn't find a punctuated number - do the regular getword thing */
    g_string_truncate(word,0);
    for (;g_unichar_isdigit(g_utf8_get_char(*ptr)) ||
      g_unichar_isalpha(g_utf8_get_char(*ptr)) ||
      g_utf8_get_char(*ptr)=='\'';*ptr=g_utf8_next_char(*ptr))
	g_string_append_unichar(word,g_utf8_get_char(*ptr));
    return g_string_free(word,FALSE);
}

/*
 * isroman:
 *
 * Is this word a Roman Numeral?
 *
 * It doesn't actually validate that the number is a valid Roman Numeral--for
 * example it will pass MXXXXXXXXXX as a valid Roman Numeral, but that's not
 * what we're here to do. If it passes this, it LOOKS like a Roman numeral.
 * Anyway, the actual Romans were pretty tolerant of bad arithmetic, or
 * expressions thereof, except when it came to taxes. Allow any number of M,
 * an optional D, an optional CM or CD, any number of optional Cs, an optional
 * XL or an optional XC, an optional IX or IV, an optional V and any number
 * of optional Is.
 */
gboolean isroman(const char *t)
{
    const char *s;
    if (!t || !*t)
	return FALSE;
    s=t;
    while (g_utf8_get_char(t)=='m' && *t)
	t++;
    if (g_utf8_get_char(t)=='d')
	t++;
    if (g_str_has_prefix(t,"cm"))
	t+=2;
    if (g_str_has_prefix(t,"cd"))
	t+=2;
    while (g_utf8_get_char(t)=='c' && *t)
	t++;
    if (g_str_has_prefix(t,"xl"))
	t+=2;
    if (g_str_has_prefix(t,"xc"))
	t+=2;
    if (g_utf8_get_char(t)=='l')
	t++;
    while (g_utf8_get_char(t)=='x' && *t)
	t++;
    if (g_str_has_prefix(t,"ix"))
	t+=2;
    if (g_str_has_prefix(t,"iv"))
	t+=2;
    if (g_utf8_get_char(t)=='v')
	t++;
    while (g_utf8_get_char(t)=='i' && *t)
	t++;
    return !*t;
}

/*
 * postprocess_for_DP:
 *
 * Invoked with the -d switch from flgets().
 * It simply "removes" from the line a hard-coded set of common
 * DP-specific tags, so that the line passed to the main routine has
 * been pre-cleaned of DP markup.
 */
void postprocess_for_DP(char *theline)
{
    char *s,*t;
    int i;
    if (!*theline) 
	return;
    for (i=0;*DPmarkup[i];i++)
	while ((s=strstr(theline,DPmarkup[i])))
	{
	    t=s+strlen(DPmarkup[i]);
	    memmove(s,t,strlen(t)+1);
	}
}

/*
 * postprocess_for_HTML:
 *
 * Invoked with the -m switch from flgets().
 * It simply "removes" from the line a hard-coded set of common
 * HTML tags and "replaces" a hard-coded set of common HTML
 * entities, so that the line passed to the main routine has
 * been pre-cleaned of HTML.
 */
void postprocess_for_HTML(char *theline)
{
    while (losemarkup(theline))
	;
    loseentities(theline);
}

char *losemarkup(char *theline)
{
    char *s,*t;
    int i;
    s=strchr(theline,'<');
    t=s?strchr(s,'>'):NULL;
    if (!s || !t)
	return NULL;
    for (i=0;*markup[i];i++)
	if (tagcomp(g_utf8_next_char(s),markup[i]))
	{
	    t=g_utf8_next_char(t);
	    memmove(s,t,strlen(t)+1);
	    return s;
	}
    /* It's an unrecognized <xxx>. */
    return NULL;
}

void loseentities(char *theline)
{
    int i;
    gsize nb;
    char *amp,*scolon;
    gchar *s,*t;
    gunichar c;
    GTree *entities=NULL;
    static GIConv translit=(GIConv)-1,to_utf8=(GIConv)-1;
    if (!theline)
    {
	if (entities)
	    g_tree_destroy(entities);
	entities=NULL;
	if (translit!=(GIConv)-1)
	    g_iconv_close(translit);
	translit=(GIConv)-1;
	if (to_utf8!=(GIConv)-1)
	    g_iconv_close(to_utf8);
	to_utf8=(GIConv)-1;
	return;
    }
    if (!*theline)
	return;
    if (!entities)
    {
	entities=g_tree_new((GCompareFunc)strcmp);
	for(i=0;i<G_N_ELEMENTS(HTMLentities);i++)
	    g_tree_insert(entities,HTMLentities[i].name,
	      GUINT_TO_POINTER(HTMLentities[i].c));
    }
    if (translit==(GIConv)-1)
	translit=g_iconv_open("ISO_8859-1//TRANSLIT","UTF-8");
    if (to_utf8==(GIConv)-1)
	to_utf8=g_iconv_open("UTF-8","ISO_8859-1");
    while((amp=strchr(theline,'&')))
    {
	scolon=strchr(amp,';');
	if (scolon)
	{
	    if (amp[1]=='#')
	    {
		if (amp+2+strspn(amp+2,"0123456789")==scolon)
		    c=strtol(amp+2,NULL,10);
		else if (amp[2]=='x' &&
		  amp+3+strspn(amp+3,"0123456789abcdefABCDEF")==scolon)
		    c=strtol(amp+3,NULL,16);
	    }
	    else
	    {
		s=g_strndup(amp+1,scolon-(amp+1));
	        c=GPOINTER_TO_UINT(g_tree_lookup(entities,s));
		g_free(s);
	    }
	}
	else
	    c=0;
	if (c)
	{
	    theline=amp;
	    if (c<128 || c>=192 && c<=255)	/* An ISO-8859-1 character */
		theline+=g_unichar_to_utf8(c,theline);
	    else
	    {
		s=g_malloc(6);
		nb=g_unichar_to_utf8(c,s);
		t=g_convert_with_iconv(s,nb,translit,NULL,&nb,NULL);
		g_free(s);
		s=g_convert_with_iconv(t,nb,to_utf8,NULL,&nb,NULL);
		g_free(t);
		memcpy(theline,s,nb);
		g_free(s);
		theline+=nb;
	    }
	    memmove(theline,g_utf8_next_char(scolon),
	      strlen(g_utf8_next_char(scolon))+1);
	}
	else
	    theline=g_utf8_next_char(amp);
    }
}

gboolean tagcomp(const char *strin,const char *basetag)
{
    gboolean retval;
    gchar *s,*t;
    if (g_utf8_get_char(strin)=='/')
	t=g_utf8_casefold(g_utf8_next_char(strin),-1); /* ignore a slash */
    else
	t=g_utf8_casefold(strin,-1);
    s=g_utf8_casefold(basetag,-1);
    retval=g_str_has_prefix(t,s);
    g_free(s);
    g_free(t);
    return retval;
}

void proghelp(GOptionContext *context)
{
    gchar *help;
    fputs("Bookloupe version " PACKAGE_VERSION ".\n",stderr);
    fputs("Copyright 2000-2005 Jim Tinsley <jtinsley@pobox.com>.\n",stderr);
    fputs("Copyright 2012- J. Ali Harlow <ali@juiblex.co.uk>.\n",stderr);
    fputs("Bookloupe comes wih ABSOLUTELY NO WARRANTY. "
      "For details, read the file COPYING.\n",stderr);
    fputs("This is Free Software; "
      "you may redistribute it under certain conditions (GPL);\n",stderr);
    fputs("read the file COPYING for details.\n\n",stderr);
    help=g_option_context_get_help(context,TRUE,NULL);
    fputs(help,stderr);
    g_free(help);
    fputs("Sample usage: bookloupe warpeace.txt\n\n",stderr);
    fputs("Bookloupe queries anything it thinks shouldn't be in a PG text; "
      "non-ASCII\n",stderr);
    fputs("characters like accented letters, "
      "lines longer than 75 or shorter than 55,\n",stderr);
    fputs("unbalanced quotes or brackets, "
      "a variety of badly formatted punctuation, \n",stderr);
    fputs("HTML tags, some likely typos. "
      "It is NOT a substitute for human judgement.\n",stderr);
    fputs("\n",stderr);
}
