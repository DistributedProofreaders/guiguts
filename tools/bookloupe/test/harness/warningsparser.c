#include <stdlib.h>
#include <string.h>
#include <glib.h>
#include "testcase.h"
#include "warningsparser.h"

/*
 * A GMarkupParser for the contents of a WARNINGS tag.
 */

typedef struct {
    Testcase *testcase;
    TestcaseWarning *warning;
    TestcaseLocation *location;
    enum {
	WARNINGS_INIT,
	WARNINGS_IN_EXPECTED,
	WARNINGS_IN_WARNING,
	WARNINGS_IN_AT,
	WARNINGS_IN_TEXT,
	WARNINGS_DONE,
    } state;
} WarningsBaton;

static void warnings_parser_start_element(GMarkupParseContext *context,
  const char *element_name,const char **attribute_names,
  const char **attribute_values,void *user_data,GError **error)
{
    int i;
    guint64 tmp;
    char *endp;
    WarningsBaton *baton=user_data;
    switch(baton->state)
    {
	case WARNINGS_INIT:
	    if (strcmp(element_name,"expected"))
		g_set_error(error,G_MARKUP_ERROR,G_MARKUP_ERROR_UNKNOWN_ELEMENT,
		  "Unknown root element: '%s'",element_name);
	    else if (attribute_names[0])
		g_set_error(error,G_MARKUP_ERROR,
		  G_MARKUP_ERROR_UNKNOWN_ATTRIBUTE,
		  "Unknown attribute on element 'expected': '%s'",
		  attribute_names[0]);
	    else
		baton->state=WARNINGS_IN_EXPECTED;
	    break;
	case WARNINGS_IN_EXPECTED:
	    baton->warning=g_new0(TestcaseWarning,1);
	    if (!strcmp(element_name,"error"))
		baton->warning->is_real=TRUE;
	    else if (!strcmp(element_name,"false-positive"))
		baton->warning->xfail=TRUE;
	    else if (!strcmp(element_name,"false-negative"))
		baton->warning->is_real=baton->warning->xfail=TRUE;
	    else
	    {
		g_set_error(error,G_MARKUP_ERROR,G_MARKUP_ERROR_UNKNOWN_ELEMENT,
		  "Unknown element in 'expected': '%s'",element_name);
		g_free(baton->warning);
		baton->warning=NULL;
		return;
	    }
	    if (attribute_names[0])
	    {
		g_set_error(error,G_MARKUP_ERROR,
		  G_MARKUP_ERROR_UNKNOWN_ATTRIBUTE,
		  "Unknown attribute on element '%s': '%s'",element_name,
		  attribute_names[0]);
		g_free(baton->warning);
		baton->warning=NULL;
		return;
	    }
	    else
		baton->state=WARNINGS_IN_WARNING;
	    break;
	case WARNINGS_IN_WARNING:
	    if (!strcmp(element_name,"at"))
	    {
		baton->location=g_new0(TestcaseLocation,1);
		for(i=0;attribute_names[i];i++)
		{
		    if (!strcmp(attribute_names[i],"line"))
		    {
			tmp=g_ascii_strtoull(attribute_values[i],&endp,0);
			if (tmp<1 || tmp>G_MAXUINT || tmp==G_MAXUINT64)
			{
			    g_set_error(error,G_MARKUP_ERROR,
			      G_MARKUP_ERROR_INVALID_CONTENT,"Invalid value "
			      "for attribute 'line' on element '%s': '%s'",
			      element_name,attribute_values[i]);
			    return;
			}
			baton->location->line=(guint)tmp;
		    }
		    else if (!strcmp(attribute_names[i],"column"))
		    {
			tmp=g_ascii_strtoull(attribute_values[i],&endp,0);
			if (tmp<1 || tmp>G_MAXUINT || tmp==G_MAXUINT64)
			{
			    g_set_error(error,G_MARKUP_ERROR,
			      G_MARKUP_ERROR_INVALID_CONTENT,"Invalid value "
			      "for attribute 'column' on element '%s': '%s'",
			      element_name,attribute_values[i]);
			    return;
			}
			baton->location->column=(guint)tmp;
		    }
		    else
		    {
			g_set_error(error,G_MARKUP_ERROR,
			  G_MARKUP_ERROR_UNKNOWN_ATTRIBUTE,
			  "Unknown attribute on element '%s': '%s'",
			  element_name,attribute_names[i]);
			return;
		    }
		}
		if (!baton->location->line)
		{
		    g_set_error(error,G_MARKUP_ERROR,
		      G_MARKUP_ERROR_MISSING_ATTRIBUTE,
		      "Missing attribute on element '%s': 'line'",element_name);
		    return;
		}
		baton->state=WARNINGS_IN_AT;
	    }
	    else if (!strcmp(element_name,"text"))
	    {
		if (attribute_names[0])
		{
		    g_set_error(error,G_MARKUP_ERROR,
		      G_MARKUP_ERROR_UNKNOWN_ATTRIBUTE,
		      "Unknown attribute on element 'text': '%s'",
		      attribute_names[0]);
		    return;
		}
		baton->state=WARNINGS_IN_TEXT;
	    }
	    break;
	case WARNINGS_IN_AT:
	    g_set_error(error,G_MARKUP_ERROR,G_MARKUP_ERROR_UNKNOWN_ELEMENT,
	      "Unknown element in 'at': '%s'",element_name);
	    return;
	case WARNINGS_IN_TEXT:
	    g_set_error(error,G_MARKUP_ERROR,G_MARKUP_ERROR_UNKNOWN_ELEMENT,
	      "Unknown element in 'text': '%s'",element_name);
	    return;
	default:
	    g_set_error(error,G_MARKUP_ERROR,G_MARKUP_ERROR_UNKNOWN_ELEMENT,
	      "Unexpected element: '%s'",element_name);
	    return;
    }
}

static void warnings_parser_end_element(GMarkupParseContext *context,
  const char *element_name,void *user_data,GError **error)
{
    WarningsBaton *baton=user_data;
    switch(baton->state)
    {
	case WARNINGS_IN_EXPECTED:
	    baton->testcase->warnings=
	      g_slist_reverse(baton->testcase->warnings);
	    baton->state=WARNINGS_DONE;
	    break;
	case WARNINGS_IN_WARNING:
	    baton->warning->locations=
	      g_slist_reverse(baton->warning->locations);
	    baton->testcase->warnings=g_slist_prepend(baton->testcase->warnings,
	      baton->warning);
	    baton->warning=NULL;
	    baton->state=WARNINGS_IN_EXPECTED;
	    break;
	case WARNINGS_IN_AT:
	    baton->warning->locations=g_slist_prepend(baton->warning->locations,
	      baton->location);
	    baton->location=NULL;
	    baton->state=WARNINGS_IN_WARNING;
	    break;
	case WARNINGS_IN_TEXT:
	    baton->state=WARNINGS_IN_WARNING;
	    break;
	default:
	    g_set_error(error,G_MARKUP_ERROR,G_MARKUP_ERROR_UNKNOWN_ELEMENT,
	      "Unexpected element ending: '%s'",element_name);
	    return;
    }
}

static void warnings_parser_text(GMarkupParseContext *context,
  const char *text,gsize text_len,void *user_data,GError **error)
{
    char *s,*t;
    WarningsBaton *baton=user_data;
    switch(baton->state)
    {
	case WARNINGS_IN_EXPECTED:
	    if (strspn(text," \t\n")!=text_len)
		g_set_error(error,G_MARKUP_ERROR,G_MARKUP_ERROR_INVALID_CONTENT,
		  "The 'expected' tag does not take any content");
	    break;
	case WARNINGS_IN_WARNING:
	    if (strspn(text," \t\n")!=text_len)
		g_set_error(error,G_MARKUP_ERROR,G_MARKUP_ERROR_INVALID_CONTENT,
		  "The warning tags do not take any content");
	    break;
	case WARNINGS_IN_AT:
	    if (strspn(text," \t\n")!=text_len)
		g_set_error(error,G_MARKUP_ERROR,G_MARKUP_ERROR_INVALID_CONTENT,
		  "The 'at' tag does not take any content");
	    break;
	case WARNINGS_IN_TEXT:
	    s=g_strdup(text+strspn(text," \t\n"));
	    g_strchomp(s);
	    if (baton->warning->text)
	    {
		t=g_strconcat(baton->warning->text,s,NULL);
		g_free(baton->warning->text);
		g_free(s);
		baton->warning->text=t;
	    }
	    else
		baton->warning->text=s;
	    break;
	default:
	    g_set_error(error,G_MARKUP_ERROR,G_MARKUP_ERROR_INVALID_CONTENT,
	      "Unexpected content: '%s'",text);
	    return;
    }
}

GMarkupParseContext *warnings_parse_context_new(Testcase *testcase)
{
    static GMarkupParser parser={0};
    WarningsBaton *baton;
    parser.start_element=warnings_parser_start_element;
    parser.end_element=warnings_parser_end_element;
    parser.text=warnings_parser_text;
    baton=g_new0(WarningsBaton,1);
    baton->testcase=testcase;
    baton->state=WARNINGS_INIT;
    return g_markup_parse_context_new(&parser,
      G_MARKUP_TREAT_CDATA_AS_TEXT|G_MARKUP_PREFIX_ERROR_POSITION,
      baton,g_free);
}
