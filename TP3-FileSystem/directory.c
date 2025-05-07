#include "directory.h"
#include "inode.h"
#include "diskimg.h"
#include "file.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>

/**
 * TODO
 */
int directory_findname(struct unixfilesystem *fs, const char *name,
                       int dirinumber, struct direntv6 *dirEnt)
{
  struct inode in;
  if (inode_iget(fs, dirinumber, &in) < 0)
    return -1;

  if (!(in.i_mode & IALLOC) || (in.i_mode & IFMT) != IFDIR)
    return -1;

  int size = inode_getsize(&in);
  int numBlocks = (size + DISKIMG_SECTOR_SIZE - 1) / DISKIMG_SECTOR_SIZE;
  char buf[DISKIMG_SECTOR_SIZE];

  for (int bno = 0; bno < numBlocks; bno++)
  {
    int bytes = file_getblock(fs, dirinumber, bno, buf);
    if (bytes < 0)
      return -1;

    int entries = bytes / sizeof(struct direntv6);
    struct direntv6 *entriesList = (struct direntv6 *)buf;

    for (int i = 0; i < entries; i++)
    {
      if (strncmp(entriesList[i].d_name, name, sizeof(entriesList[i].d_name)) == 0)
      {
        *dirEnt = entriesList[i];
        return 0;
      }
    }
  }

  return -1; // Not found
}
