/*timing parameters
tRC 50
- ACTIVATE-to-ACTIVATE or REFRESH command period

tRAS 36
- ACTIVATE-to-PRECHARGE command period
- During READs and WRITEs with auto precharge, the DDR3 SDRAM will hold off the internal PRECHARGE command until tRAS (MIN) has been satisfied.

tRRD 6
- ACTIVATE-to-ACTIVATE minimum command period
- pg 153

tRP 14
- PRECHARGE command period
- Following the PRECHARGE command, a subsequent command to the same bank cannot be issued until tRP is met
- pg 118, 159, 160

tRFC 172
- REFRESH-to-ACTIVATE or REFRESH command period
- Should the clock rate be larger than tRFC (MIN), an AUTO REFRESH command should have at least one NOP command between it and another AUTO REFRESH command. Additionally, if the clock rate is slower than 40ns (25 MHz), all REFRESH commands should be followed by a PRECHARGE ALL command.
- The REFRESH period begins when the REFRESH command is registered and ends tRFC (MIN) later.
- Only NOP and DES commands are allowed after a REFRESH command and until tRFC (MIN) is satisfied.
- pg 118

tCWL(tCWD) 10
- CAS WRITE latency
- pg 142

tCAS (CL) 14
- CAS READ latency
- CAS latency is the delay, in clock cycles, between the internal READ command and the availability of the first bit of output data.
- pg 136

tRCD 14
- ACTIVATE to internal READ or WRITE delay time
- After a row is opened with an ACTIVATE command, a READ or WRITE command may be issued to that row, subject to the tRCD specification.
- pg 153

tWR 16
- Write recovery time
- Data for any WRITE burst may be followed by a subsequent PRECHARGE command providing tWR has been met
- The write recovery time (tWR) is referenced from the first rising clock edge after the last write data is shown
- tWR specifies the last burst WRITE cycle until the PRECHARGE command can be issued to the same bank
- pg 173

tRTP 8
- READ-to-PRECHARGE time
- A READ burst may be followed by a PRECHARGE command to the same bank provided auto precharge is not activated. The minimum READ-to-PRECHARGE command spacing to the same bank is four clocks and must also satisfy a minimum analog time from the READ command. This time is called tRTP (READ-to-PRECHARGE).
- pg 159

tCCD 4
- CAS#-to-CAS# command delay
- When at least one bank is open, any READ-to-READ command delay or WRITE-toWRITE command delay is restricted to tCCD (MIN).
- Data from any READ burst may be concatenated with data from a subsequent READ command to provide a continuous flow of data. The first data element from the new burst follows the last element of a completed burst. The new READ command should be issued tCCD cycles after the first READ command.
- Data for any WRITE burst may be concatenated with a subsequent WRITE command to provide a continuous flow of input data. The new WRITE command can be tCCD clocks following the previous WRITE command. The first data element from the new burst is applied after the last element of a completed burst.
- pg 157, 159

tBURST 4

tWTR 8
- Delay from start of internal WRITE transaction to internal READ command
- Data for any WRITE burst may be followed by a subsequent READ command after tWTR has been met
- tWTR controls the WRITE-to-READ delay to the same device and starts with the first rising clock edge after the last write data
- pg 170
*/

/*DRAM Commmands
ACT<BANK><ROW> //row activate
PRE<BANK> //bank precharge
RD<BANK><COLUMN> //column read
RDAP<BANK><COLUMN> //Read auto precharge
WRAP<BANK><COLUMN> //read auto prechange
REF // refresh -- optional 


//case of a single write on tick 0, no subsequent action by processor
//if not already precharged: READ = Precharge then Activate (wait tRCD, unless additive latency has been correctly preprogrammed) then READ
//See page 150 for a breakdown. If a bank is open, a READ-READ or WRITE-WRITE command is limited by tCCD (not given in specifications)
tRC is min time between successive Activate commands (in one bank)
tRRD is min time between activates to different banks
Read value is available tCAS after row operations.
so READ: Precharge + tRC+tCAS = Time till data is output
