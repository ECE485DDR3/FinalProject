// must insert utlist.h into the same directory as this file
// to compile "gcc -o readQueue readQueue.c"
// to run "./readQueue <file-name.txt>"


#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "utlist.h"


//linear linked list structure for input file data
typedef struct inputData
{
	int addr;
	char instruction[64];
	int clk;
	struct inputData * next;
}inputData;

//linear linked list structure for data stored in the queue
typedef struct queueData
{
    int addr;
    char instruction[64];
    struct queueData * next;
}queueData;

//Prototypes
void get_file(inputData ** head, char * inputFile);


//main function
int main(int argc, char *argv[])
{
    inputData * inputHead = NULL;
    queueData * queueHead = NULL;
    queueData * temp;
    queueData * queueCurrent;
    int cpuClk = 0;
    int i;


    //program usage
    if(argc != 2)
    {
    	printf("usage: %s filename", argv[0]);
    	return 0;
    }

    get_file(&inputHead, argv[1]);

    //print input lines
    /*
    while(inputHead != NULL)
    {
        printf("addr = %08x instruction = %s clk = %d\n",inputHead -> addr, inputHead -> instruction, inputHead -> clk);
        LL_DELETE(inputHead, inputHead);
    }
    */

    //add to queue
    while(inputHead != NULL)
    {
        //add to queue if cpu clk has reached when to add
        if(cpuClk == inputHead -> clk)
        {
            temp = (queueData *) malloc(sizeof(queueData));

            temp -> addr = inputHead -> addr;
            strncpy(temp -> instruction, inputHead -> instruction, 64);

            LL_APPEND(queueHead, temp);
            LL_DELETE(inputHead, inputHead);

            i = 1;
        }

        else
        {
            i = 0;
        }


        //print queue contents if a new item was added (and also at the very first cpu clock tick)
        if(i == 1 || cpuClk == 0)
        {
            printf("cpuClk = %d\n", cpuClk);

            queueCurrent = queueHead;

            if(queueCurrent == NULL)
            {
                printf("queue is empty\n");
            }

            while(queueCurrent != NULL)
            {
                printf("queue -> address = %08x, queue -> instruction = %s\n", queueCurrent -> addr, queueCurrent -> instruction);
                queueCurrent = queueCurrent -> next;
            }
            printf("\n");
        }

        ++cpuClk;
    }

    //empty queue
    while(queueHead != NULL)
    {
        LL_DELETE(queueHead, queueHead);
    }

    return 0;
}



/*
 * This function opens the input file and sorts the contents into a linked list holding the address the instruction should be executed at, the
 * instruction that should be executed, and the clock tick that the instruction should sent to the DRAM
 * 
 * INPUT:
 * head - a pointer to the head pointer of where to save the input data to
 * inputFile - name of the file to get the instructions from
 */
void get_file(inputData ** head, char * inputFile)
{
    FILE * fp;
    char line[255];
    char * buf;

    inputData * temp;

    //open file
    fp = fopen(inputFile, "r");

    //go through each line in the input file
    while(fgets(line, 255, (FILE*)fp) != NULL)
    {
        temp = (inputData *) malloc(sizeof(inputData));

        //get address
        buf = strtok(line, " ");
        temp -> addr = strtol(buf, NULL, 16);
        //printf(".%08x.\n",temp -> addr);

        //get instruction
        buf = strtok(NULL, " ");
        strncpy(temp -> instruction, buf, 64);
        //printf(".%s.\n",temp -> instruction);

        //get clock number
        buf = strtok(NULL, " ");
        temp -> clk = strtol(buf, NULL, 10);
        //printf(".%d.\n",temp -> clk);

        //add to linked list of all the input lines
        LL_APPEND((*head), temp);
    }

    //close file pointer
    fclose(fp);

    return;
}