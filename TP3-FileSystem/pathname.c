
#include "pathname.h"
#include "directory.h"
#include "inode.h"
#include "diskimg.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>

/**
 * TODO
 */
int pathname_lookup(struct unixfilesystem *fs, const char *pathname)
{
    if (!pathname || pathname[0] != '/')
        return -1; // (mal input)

    int inumber = ROOT_INUMBER;

    // Make a copy to tokenize (strtok modifies the string)
    char pathcopy[1024];
    strncpy(pathcopy, pathname, sizeof(pathcopy));
    pathcopy[sizeof(pathcopy) - 1] = '\0';

    char *token = strtok(pathcopy, "/");
    while (token != NULL)
    {
        struct direntv6 entry;
        if (directory_findname(fs, token, inumber, &entry) < 0)
        {
            return -1; // (mal input)
        }
        inumber = entry.d_inumber;
        token = strtok(NULL, "/");
    }

    return inumber;
}
