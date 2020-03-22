#include <stdlib.h>
#include <stdio.h>
#ifndef WIN32
#include <sys/wait.h>
#endif
#include <bl/bl.h>

#define SPAWN_BUFSIZE	128

gboolean spawn_sync(const char *working_directory,char **argv,
  char **standard_output,int *exit_status,GError **error)
{
/* Don't use g_spawn_sync on WIN32 for now to avoid needing the helper */
#ifndef WIN32
    char *standard_error=NULL;
    gboolean retval;
    GSpawnFlags flags=G_SPAWN_SEARCH_PATH;
    if (!standard_output)
	flags=G_SPAWN_STDOUT_TO_DEV_NULL;
    retval=g_spawn_sync(working_directory,argv,NULL,flags,NULL,NULL,
      standard_output,&standard_error,exit_status,error);
    if (standard_error)
	g_printerr("%s",standard_error);
    g_free(standard_error);
    if (retval && exit_status)
	*exit_status=WEXITSTATUS(*exit_status);
    return retval;
#else
    FILE *fp;
    int i,r;
    size_t n,len;
    char *current_dir;
    GString *command_line,*string;
    if (working_directory)
    {
	current_dir=g_get_current_dir();
	if (g_chdir(working_directory)<0)
	{
	    g_set_error(error,G_FILE_ERROR,g_file_error_from_errno(errno),
	      "%s: %s",working_directory,g_strerror(errno));
	    g_free(current_dir);
	    return FALSE;
	}
    }
    else
	current_dir=NULL;
    command_line=g_string_new(NULL);
    for(i=0;argv[i];i++)
    {
	if (i)
	    g_string_append_c(command_line,' ');
	g_string_append(command_line,argv[i]);
    }
    fp=popen(command_line->str,"r");
    g_string_free(command_line,TRUE);
    if (current_dir)
    {
	if (g_chdir(current_dir)<0)
	    g_error("Failed to restore current directory: %s",
	      g_strerror(errno));
	g_free(current_dir);
    }
    if (!fp)
    {
	g_set_error(error,G_FILE_ERROR,g_file_error_from_errno(errno),
	  "%s: %s",command_line->str,g_strerror(errno));
	return FALSE;
    }
    string=g_string_new(NULL);
    do
    {
	len=string->len;
	g_string_set_size(string,len+SPAWN_BUFSIZE);
	n=fread(string->str+len,1,SPAWN_BUFSIZE,fp);
	if (n<0)
	{
	    g_set_error(error,G_FILE_ERROR,g_file_error_from_errno(errno),
	      "Error reading from bookloupe: %s",g_strerror(errno));
	    (void)pclose(fp);
	    g_string_free(string,TRUE);
	    return FALSE;
	}
	g_string_set_size(string,len+n);
    } while(n);
    r=pclose(fp);
    if (r<0)
    {
	g_set_error(error,G_FILE_ERROR,g_file_error_from_errno(errno),
	  "Error reading from bookloupe: %s",g_strerror(errno));
	g_string_free(string,TRUE);
	return FALSE;
    }
    else
    {
	if (exit_status)
	    *exit_status=r;
	if (standard_output)
	    *standard_output=g_string_free(string,FALSE);
	else
	    g_string_free(string,TRUE);
	return TRUE;
    }
#endif
}
