#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include "inode.h"
#include "diskimg.h"

int inode_iget(struct unixfilesystem *fs, int inumber, struct inode *inp)
{
    if (inumber < 1 || inumber >= fs->superblock.s_isize * 16)
    {
        return -1; // Invalid inumber
    }

    int sector = INODE_START_SECTOR + (inumber - 1) / 16;
    int offset = (inumber - 1) % 16;

    struct inode buffer[16];

    if (diskimg_readsector(fs->dfd, sector, buffer) != DISKIMG_SECTOR_SIZE)
    {
        return -1; // Read error
    }

    *inp = buffer[offset];
    return 0;
}

int inode_indexlookup(struct unixfilesystem *fs, struct inode *inp, int blockNum)
{
    if (!(inp->i_mode & IALLOC))
        return -1;

    if (!(inp->i_mode & ILARG))
    {
        // Direct blocks
        if (blockNum < 0 || blockNum >= 8)
            return -1;
        return inp->i_addr[blockNum];
    }

    // Large file: single-indirect blocks
    if (blockNum < 7 * 256)
    {
        int indirectBlock = blockNum / 256;
        int offset = blockNum % 256;

        uint16_t sector[256];
        int sectorNum = inp->i_addr[indirectBlock];
        if (sectorNum == 0)
            return -1;

        if (diskimg_readsector(fs->dfd, sectorNum, sector) != DISKIMG_SECTOR_SIZE)
            return -1;

        return sector[offset];
    }

    // Double-indirect blocks
    int adjustedBlockNum = blockNum - (7 * 256);
    int firstIndex = adjustedBlockNum / 256;
    int secondIndex = adjustedBlockNum % 256;

    if (firstIndex >= 256)
        return -1;

    uint16_t dblSector[256];
    int dblSectorNum = inp->i_addr[7];
    if (dblSectorNum == 0)
        return -1;

    if (diskimg_readsector(fs->dfd, dblSectorNum, dblSector) != DISKIMG_SECTOR_SIZE)
        return -1;

    int indirectBlockNum = dblSector[firstIndex];
    if (indirectBlockNum == 0)
        return -1;

    uint16_t indirectSector[256];
    if (diskimg_readsector(fs->dfd, indirectBlockNum, indirectSector) != DISKIMG_SECTOR_SIZE)
        return -1;

    return indirectSector[secondIndex];
}

int inode_getsize(struct inode *inp)
{
    return ((inp->i_size0 << 16) | inp->i_size1);
}
