#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include "file.h"
#include "inode.h"
#include "diskimg.h"

/**
 * TODO
 */
int file_getblock(struct unixfilesystem *fs, int inumber, int blockNum, void *buf)
{
    struct inode in;
    if (inode_iget(fs, inumber, &in) < 0)
    {
        return -1;
    }

    int sectorNum = inode_indexlookup(fs, &in, blockNum);
    if (sectorNum == -1)
    {
        return -1;
    }

    if (diskimg_readsector(fs->dfd, sectorNum, buf) != DISKIMG_SECTOR_SIZE)
    {
        return -1;
    }

    int size = inode_getsize(&in);
    int fileBlockOffset = blockNum * DISKIMG_SECTOR_SIZE;

    if (fileBlockOffset + DISKIMG_SECTOR_SIZE > size)
    {
        // Last block: only part of the block is valid
        return size - fileBlockOffset;
    }
    else
    {
        // Full block is valid
        return DISKIMG_SECTOR_SIZE;
    }
}
