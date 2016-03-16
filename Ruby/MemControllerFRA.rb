#!/usr/bin/ruby

class ParseCpuRequests

  $fileRequest = Array.new
  $CpuClock = 0
  $DRAMClock = 0
  $CPUBuffer = Array.new
  $goFetch = 1
  $openPage = Array.new

  $prevCommands = Array.new
  for i in 0..7
    $prevCommands.push(Hash["ACT" => Float::INFINITY,
                            "PRE" => Float::INFINITY,
                            "RD" => Float::INFINITY,
                            "RDAP" => Float::INFINITY,
                            "WR" => Float::INFINITY,
                            "WRAP" => Float::INFINITY,
                            "REF" => Float::INFINITY
                           ])
  end

  #loads all each line from the external file into an array called $fileRequest
  def getOneRequestFromFile
    #get input line from file
    in_line = $file.gets

    #not end of file
    if(in_line != nil)
      whole_address = in_line.downcase.split(/\W+/)[0]
      check_address = in_line.downcase.sub(/0x/, "").split(/\W+/)[0]
      check_inst = in_line.upcase.split(/\W+/)[1]
      check_cpuTime = in_line.split(/\W+/)[2]

      #verify input line has 3 arguments
      if in_line.split(/\W+/).size != 3
        #$outfile.syswrite "Error in CPU request [#{in_line}] - wrong number of parameters, should be [<address> <instruction> <CPU clock>], skipping\n"    #outputFile display
        puts "Error in CPU request [#{in_line.strip}] - wrong number of parameters, should be [<address> <instruction> <CPU clock>], skipping\n"    #Terminal display
        getOneRequestFromFile

      #verify address begins with 0x
      elsif !whole_address.start_with?("0x")
        #$outfile.syswrite "Error in CPU request [#{whole_address} #{check_inst} #{check_cpuTime}] - address not hex (must begin with '0x'), skipping\n"    #outputFile display
        puts "Error in CPU request [#{whole_address} #{check_inst} #{check_cpuTime}] - address not hex (must begin with '0x'), skipping\n"    #Terminal display
        getOneRequestFromFile

      #verify address is 32 bits (8 hex digits)
      elsif check_address.size != 8
        #$outfile.syswrite "Error in CPU request [#{whole_address} #{check_inst} #{check_cpuTime}] - invalid address size, skipping\n"    #outputFile display
        puts "Error in CPU request [#{whole_address} #{check_inst} #{check_cpuTime}] - invalid address size, skipping\n"    #Terminal display
        getOneRequestFromFile

      #verify address only contains hex digits
      elsif check_address[/\H/]
        #$outfile.syswrite "Error in CPU request [#{whole_address} #{check_inst} #{check_cpuTime}] - address not hex, skipping\n"    #outputFile display
        puts "Error in CPU request [#{whole_address} #{check_inst} #{check_cpuTime}] - address not hex, skipping\n"    #Terminal display
        getOneRequestFromFile

      #verify instructions are valid
      elsif ((check_inst != "READ") & (check_inst != "WRITE") & (check_inst != "IFETCH"))
        #$outfile.syswrite "Error in CPU request [#{whole_address} #{check_inst} #{check_cpuTime}] - invalid instruction name, skipping\n"    #outputFile display
        puts "Error in CPU request [#{whole_address} #{check_inst} #{check_cpuTime}] - invalid instruction name, skipping\n"    #Terminal display
        getOneRequestFromFile

      #verify cpu time is base 10
      elsif check_cpuTime.to_i.to_s != check_cpuTime
        #$outfile.syswrite "Error in CPU request [#{whole_address} #{check_inst} #{check_cpuTime}] - invalid value for CPU Time, skipping\n"    #outputFile display
        puts "Error in CPU request [#{whole_address} #{check_inst} #{check_cpuTime}] - invalid value for CPU Time, skipping\n"    #Terminal display
        getOneRequestFromFile

      #verify cpu time is not in past
      elsif check_cpuTime.to_i < $CpuClock
        #$outfile.syswrite "Error in CPU request [#{whole_address} #{check_inst} #{check_cpuTime}] - violates current CPU time (#{$CpuClock}), skipping\n"    #outputFile display
        puts "Error in CPU request [#{whole_address} #{check_inst} #{check_cpuTime}] - violates current CPU time (#{$CpuClock}), skipping\n"    #Terminal display
        getOneRequestFromFile

      #request is valid, store it
      else
        address = check_address.to_i(16).to_s(2).rjust(32,"0")

        #parse instruction into a hash: row,bank,col,instruction,cpuTime
        $fileRequest << {
                         "row" => address.split(//)[0..14].join("").to_i(2),
                         "bank" => address.split(//)[15..17].join("").to_i(2),
                         "col" => address.split(//)[18..28].join("").to_i(2),
                         "chunk" => address.split(//)[29..31].join("").to_i(2),
                         "inst" => in_line.split(/\W+/)[1],
                         "cpuTime" => in_line.split(/\W+/)[2].to_i
                        }
      end
    end
  end

  def simulateDRAMMemController
    begin
      $CpuClock = $CpuClock + 1

      #get a request from the input file
      if($goFetch == 1 && !$file.eof?())
        getOneRequestFromFile
        $goFetch = 0

        if $debug == true
          puts "CPU Clock = #{$CpuClock} DRAM Clock = #{$DRAMClock}"
          puts "Fetching CPU request from file: #{$fileRequest}\n"
        end
      end

      #attempt to add to queue
      if not $fileRequest.empty?
        #only loads the Memory Controller buffer when it's less or equal to than 16 and proper CPU time.
        if(($CPUBuffer.size() <= 16) && ($fileRequest.first["cpuTime"] == $CpuClock))
          $CPUBuffer << $fileRequest.shift
          $CPUBuffer.last["DRAMCommands"] = getCommandSequence($CPUBuffer.size-1)     #get dram commands for the newly added item to the queue
          $goFetch = 1
          recalculate = true

          if $debug == true
            puts "CPU Clock = #{$CpuClock} DRAM Clock = #{$DRAMClock}"
            puts "Adding CPU request to queue and calculating its DRAM commands"
            puts "Current queue = "
            for item in $CPUBuffer.each
              puts "                #{item}"
            end
            puts ""
          end

        #if the queue is empty (nothing being done), we can skip ahead to when an item from the input file will be added to the queue
        elsif $CPUBuffer.size() == 0
          dramSkip = ($fileRequest.first["cpuTime"] - $CpuClock + (($CpuClock - 1) % 4)) / 4     #determine how many dram cycles have gone by
          $CpuClock = $fileRequest.first["cpuTime"]     #update CpuClock
          $DRAMClock += dramSkip     #update DRAMClock
          for bankCommands in $prevCommands.each      #update number of dram cycles since previous commands
            for command in bankCommands.keys
              bankCommands[command] += dramSkip
            end
          end

          #now correct time to add the request to the queue
          $CPUBuffer << $fileRequest.shift
          $CPUBuffer.last["DRAMCommands"] = getCommandSequence($CPUBuffer.size-1)     #get dram commands for the newly added item to the queue
          $goFetch = 1
          recalculate = true

          if $debug == true
            puts "Queue is empty, skipping ahead to CPU time: #{$CpuClock}, DRAM time: #{$DRAMClock}"
            puts "Time since previous commands:"
            for i in 0..($prevCommands.size-1)
              puts "                             Bank %2d:   ACT = %5.0f   PRE = %5.0f   RD = %5.0f   RDAP = %5.0f   WR = %5.0f   WRAP = %5.0f   REF = %5.0f"\
                    % [i, $prevCommands[i]["ACT"], $prevCommands[i]["PRE"], $prevCommands[i]["RD"], $prevCommands[i]["RDAP"], $prevCommands[i]["WR"], $prevCommands[i]["WRAP"], $prevCommands[i]["REF"]]
            end
            puts "Adding CPU request to queue and calculating its DRAM commands"
            puts "Current queue = "
            for item in $CPUBuffer.each
              puts "                #{item}"
            end
            puts ""
          end
        end
      end

      #the buffers finishes one Memory request at every 200 CPU cycles (4x50 = 200)
      if($CpuClock%4 == 0)
        $DRAMClock = $DRAMClock + 1

        #each command in prevCommands array is now 1 DRAM clock older
        for bankCommands in $prevCommands.each
          for command in bankCommands.keys
            bankCommands[command] += 1
          end
        end

        #only check for dram commands if there are items in the buffer
        if not $CPUBuffer.empty?
          #only recalculate if something was added to the queue
          if recalculate == true
            getCommandList

            if $debug == true
              puts "CPU Clock = #{$CpuClock} DRAM Clock = #{$DRAMClock}"
              puts "List of dram commands with expected output times - open page policy ordering:"
              for item in $dramCommandList
                puts "          command = #{item["command"]} row = #{item["row"]} bank = #{item["bank"]} col = #{item["col"]} expectedDRAMTime = #{item["expectedDRAMTime"]}"
              end
              puts ""
            end

            reorderCommandListFRA
            
            if $debug == true
              puts "List of dram commands with expected output times - reordered for first ready first access scheduling:"
              for item in $dramCommandList
                puts "          command = #{item["command"]} row = #{item["row"]} bank = #{item["bank"]} col = #{item["col"]} expectedDRAMTime = #{item["expectedDRAMTime"]}"
              end
              puts ""
            end

            recalculate = false
          end

          if $dramCommandList.first["expectedDRAMTime"] == $DRAMClock
            #output dram command
            executeDRAMCommand($dramCommandList.first["command"], $dramCommandList.first["bank"], $dramCommandList.first["row"], $dramCommandList.first["col"])

            if $debug == true
              puts "CPU Clock = #{$CpuClock} DRAM Clock = #{$DRAMClock}"
              puts "DRAM command executed: #{$dramCommandList.first["command"]}   Bank:#{$dramCommandList.first["bank"]}   Row: #{$dramCommandList.first["row"]}   Column: #{$dramCommandList.first["col"]}"
              puts "Corresponds to CPU request: #{$dramCommandList.first["CPURequest"]}"
            end

            #update prevCommands array
            $prevCommands[$dramCommandList.first["bank"]][$dramCommandList.first["command"]] = 0

            if $debug == true
              puts "Time previous command array updated:"
              for i in 0..($prevCommands.size-1)
                puts "                             Bank %2d:   ACT = %5.0f   PRE = %5.0f   RD = %5.0f   RDAP = %5.0f   WR = %5.0f   WRAP = %5.0f   REF = %5.0f"\
                     % [i, $prevCommands[i]["ACT"], $prevCommands[i]["PRE"], $prevCommands[i]["RD"], $prevCommands[i]["RDAP"], $prevCommands[i]["WR"], $prevCommands[i]["WRAP"], $prevCommands[i]["REF"]]
              end
            end

            #remove dram command from dram command array in the queue
            $dramCommandList.first["CPURequest"]["DRAMCommands"].shift

            if $debug == true
              puts "Just executed DRAM command removed from dramCommandList"
            end

            #if request has no more dram commands, remove the request, it has been satisfied
            if $dramCommandList.first["CPURequest"]["DRAMCommands"].empty?
              if $debug == true
                puts "CPU request has been completed, removing from queue: #{$dramCommandList.first["CPURequest"]}"
              end

              $CPUBuffer.delete_at($CPUBuffer.index($dramCommandList.first["CPURequest"]))
            end

            #remove dram command from dram command list
            $dramCommandList.shift

            if $debug == true
              puts "List of dram commands with expected output times:"
              for item in $dramCommandList
                puts "          command = #{item["command"]} row = #{item["row"]} bank = #{item["bank"]} col = #{item["col"]} expectedDRAMTime = #{item["expectedDRAMTime"]}"
              end
              puts ""

              puts "Current queue = "
              for item in $CPUBuffer.each
                puts "                #{item}"
              end
              puts ""
            end
          end
        end
      end
    #not done with simulation unless queue is empty, and no more items left from the input file
    end while (!$CPUBuffer.empty?() or !$fileRequest.empty? or !$file.eof?)
  end

  def getCommandSequence(requestIndex)
    commands = Array.new

    myOpenPage = Marshal.load(Marshal.dump($openPage))
   
    #go through all the items in the queue up to the request we want to calculate the dram commands for and update the current open page
    for i in 0..(requestIndex-1)
      for j in $CPUBuffer[i]["DRAMCommands"].each
        dramCommand = j

        if dramCommand == "ACT"
          myOpenPage[$CPUBuffer[i]["bank"]] = $CPUBuffer[i]["row"]

        elsif dramCommand == "PRE" || dramCommand == "RDAP" || dramCommand == "WRAP"
          myOpenPage[$CPUBuffer[i]["bank"]] = nil
        end
      end
    end

    if (($CPUBuffer[requestIndex]['inst'] == "READ") || ($CPUBuffer[requestIndex]['inst'] == "IFETCH"))
      if myOpenPage[$CPUBuffer[requestIndex]["bank"]] == $CPUBuffer[requestIndex]["row"]
        commands.push("RD")

      elsif myOpenPage[$CPUBuffer[requestIndex]["bank"]] == nil
        commands.push("ACT")
        commands.push("RD")

      else
        commands.push("PRE")
        commands.push("ACT")
        commands.push("RD")
      end

    elsif ($CPUBuffer[requestIndex]['inst'] == "WRITE")
      if myOpenPage[$CPUBuffer[requestIndex]["bank"]] == $CPUBuffer[requestIndex]["row"]
        commands.push("WR")

      elsif myOpenPage[$CPUBuffer[requestIndex]["bank"]] == nil
        commands.push("ACT")
        commands.push("WR")

      else
        commands.push("PRE")
        commands.push("ACT")
        commands.push("WR")
      end
    end

    return commands
  end


  def getCommandTiming(myPrevCommands, dramCommand, bank)
    tRC = 50
    tRAS = 36
    tRRD = 6
    tRP = 14
    tRFC = 172
    tCWL = 10
    tCAS = 14
    tRCD = 14
    tWR = 16
    tRTP = 8
    tCCD = 4
    tBURST = 4
    tWTR = 8

    #additional time before all timing constraints are satisfied for the dramCommand
    additionalTime = 0

    #if we want to execute an activate
    if dramCommand == "ACT"
      #check prior activate to same bank
      if myPrevCommands[bank]["ACT"] < tRC
        time2satisfy = tRC - myPrevCommands[bank]["ACT"]
        if time2satisfy > additionalTime
          additionalTime = time2satisfy
        end
      end

      #check prior precharge to same bank
      if myPrevCommands[bank]["PRE"] < tRP
        time2satisfy = tRP - myPrevCommands[bank]["PRE"]
        if time2satisfy > additionalTime
          additionalTime = time2satisfy
        end
      end

      #check activates to other banks
      for interBankAct in myPrevCommands.each
        if interBankAct["ACT"] < tRRD
          time2satisfy = tRRD - interBankAct["ACT"]
          if time2satisfy > additionalTime
            additionalTime = time2satisfy
          end
        end
      end

    #if we want to execute a read
    elsif dramCommand == "RD" || dramCommand == "RDAP"
      #check prior activate to same bank
      if myPrevCommands[bank]["ACT"] < tRCD
        time2satisfy = tRCD - myPrevCommands[bank]["ACT"]
        if time2satisfy > additionalTime
          additionalTime = time2satisfy
        end
      end

      for interBankCommand in myPrevCommands.each
        #check prior reads to all banks
        if interBankCommand["RD"] < tCCD
          time2satisfy = tCCD - interBankCommand["RD"]
          if time2satisfy > additionalTime
            additionalTime = time2satisfy
          end
        end

        #check prior writes to all banks
        if interBankCommand["WR"] < (tCWL + tBURST + tWTR)
          time2satisfy = (tCWL + tBURST + tWTR) -interBankCommand["WR"]
          if time2satisfy > additionalTime
            additionalTime = time2satisfy
          end
        end
      end

    #if we want to execute a write
    elsif dramCommand == "WR" || dramCommand == "WRAP"
      #check prior activate to same bank
      if myPrevCommands[bank]["ACT"] < tRCD
        time2satisfy = tRCD - myPrevCommands[bank]["ACT"]
        if time2satisfy > additionalTime
          additionalTime = time2satisfy
        end
      end

      for interBankCommand in myPrevCommands.each
        #check prior writes to all banks
        if interBankCommand["WR"] < tCCD
          time2satisfy = tCCD - interBankCommand["WR"]
          if time2satisfy > additionalTime
            additionalTime = time2satisfy
          end
        end

        #check prior reads to all banks
        if interBankCommand["RD"] < (tCAS + tCCD + 2 - tCWL)
          time2satisfy = (tCAS + tCCD + 2 - tCWL) -interBankCommand["RD"]
          if time2satisfy > additionalTime
            additionalTime = time2satisfy
          end
        end
      end

    #if we want to execute a precharge
    elsif dramCommand == "PRE"
      #check prior activate to same bank
      if myPrevCommands[bank]["ACT"] < tRAS
        time2satisfy = tRAS - myPrevCommands[bank]["ACT"]
        if time2satisfy > additionalTime
          additionalTime = time2satisfy
        end
      end

      #check prior read to same bank
      if myPrevCommands[bank]["RD"] < tRTP
        time2satisfy = tRTP - myPrevCommands[bank]["RD"]
        if time2satisfy > additionalTime
          additionalTime = time2satisfy
        end
      end

      #check prior write same bank
      if myPrevCommands[bank]["WR"] < (tCWL + tBURST + tWR)
        time2satisfy = (tCWL + tBURST + tWR) - myPrevCommands[bank]["WR"]
        if time2satisfy > additionalTime
          additionalTime = time2satisfy
        end
      end
    end

    return additionalTime
  end

  def getCommandList
    myPrevCommands = Marshal.load(Marshal.dump($prevCommands))
    myDRAMClock = $DRAMClock
    $dramCommandList = Array.new

    #go through all the requests in the queue
    for request in $CPUBuffer.each
      #go through all the dram commands in each request
      for dramCommand in request["DRAMCommands"].each
        #get when we can issue the dram command
        additionalTime = getCommandTiming(myPrevCommands, dramCommand, request["bank"])

        #append to the end of the dram command list
        $dramCommandList.push({"command" => dramCommand,
                               "row" => request["row"],
                               "bank" => request["bank"],
                               "col" => request["col"],
                               "chunk" => request["chunk"],
                               "expectedDRAMTime" => (myDRAMClock + additionalTime),
                               "CPURequest" => request
                               })

        #update the previous commands up to the new dram clock tick
        for bankCommands in myPrevCommands.each
          for command in bankCommands.keys
            bankCommands[command] += (additionalTime + 1)
          end
        end

        #update previous commands with new command executed
        myPrevCommands[request["bank"]][dramCommand] = 1
        #update dram clock to new time
        myDRAMClock += (additionalTime + 1)
      end
    end

#puts "#{$dramCommandList}"
  end

  
  def reorderCommandListFRA
    for i in 0..($dramCommandList.size-1)
      myDRAMClock = $DRAMClock

      #can only issue this command after all commands to the same bank ahead in the queue have been issued already
      for j in 0..(i-1)
        if $dramCommandList[j]["bank"] == $dramCommandList[i]["bank"]
          myDRAMClock = $dramCommandList[j]["expectedDRAMTime"] + 1
        end
      end

      begin
        begin
          #update previous commands up to new dram clock tick
          tempDRAMClock = $DRAMClock
          myPrevCommands = Marshal.load(Marshal.dump($prevCommands))
          for j in 0..(i-1)
            if $dramCommandList[j]["expectedDRAMTime"] < myDRAMClock
              for bankCommands in myPrevCommands.each
                for command in bankCommands.keys
                  bankCommands[command] += ($dramCommandList[j]["expectedDRAMTime"] - tempDRAMClock)
                end
              end
              
              myPrevCommands[$dramCommandList[j]["bank"]][$dramCommandList[j]["command"]] = 0
              tempDRAMClock = $dramCommandList[j]["expectedDRAMTime"]

            else
              break
            end
          end

          if tempDRAMClock < myDRAMClock
            for bankCommands in myPrevCommands.each
              for command in bankCommands.keys
                bankCommands[command] += (myDRAMClock - tempDRAMClock)
              end
            end
            tempDRAMClock = myDRAMClock
          end

          #get when we can issue the dram command
          additionalTime = getCommandTiming(myPrevCommands, $dramCommandList[i]["command"], $dramCommandList[i]["bank"])
          myDRAMClock += additionalTime
        #have to repeat to see if it got pushed behind any other commands in the dram command list
        end while additionalTime != 0

        #before moving to new position, check if it conflicts with any of the commands ahead of it in the queue
        conflict = false
        myPrevCommands[$dramCommandList[i]["bank"]][$dramCommandList[i]["command"]] = 0
        tempDRAMClock = myDRAMClock
        for j in 0..(i-1)
          #new placement of the command is at the same dram clock as another item ahead of it in the dram command list
          if $dramCommandList[j]["expectedDRAMTime"] == myDRAMClock
            myDRAMClock += 1
            conflict = true
            break

          #this item in the command list is ahead of the command we want to move, but behind its new position
          elsif $dramCommandList[j]["expectedDRAMTime"] > myDRAMClock
            #update prev commands to this item's expected time
            for bankCommands in myPrevCommands.each
              for command in bankCommands.keys
                bankCommands[command] += ($dramCommandList[j]["expectedDRAMTime"] - tempDRAMClock)
              end
            end

            #see if the item is still allowed to execute at the same time it originally was
            additionalTime = getCommandTiming(myPrevCommands, $dramCommandList[j]["command"], $dramCommandList[j]["bank"])

            #the new placement of the command now delays the execution of another item ahead of it in the dram command list, but behind its new position
            if additionalTime > 0
              myDRAMClock = $dramCommandList[j]["expectedDRAMTime"] + 1
              conflict = true
              break
            end

            #update previous commands to add in this item's command
            tempDRAMClock = $dramCommandList[j]["expectedDRAMTime"]
            myPrevCommands[$dramCommandList[j]["bank"]][$dramCommandList[j]["command"]] = 0
          end
        end
      #keep repeating until no more conflicts with items ahead in the dram command list
      end while conflict == true

      #no conflicts with the new time to execute, we can move it, find its place in the dram command list
      for j in 0..(i)
        if $dramCommandList[j]["expectedDRAMTime"] > myDRAMClock
          break
        end
      end

      #insert into new position
      if j
        $dramCommandList[i]["expectedDRAMTime"] = myDRAMClock
        $dramCommandList.insert(j, $dramCommandList.delete_at(i))
      end

      #debug print
=begin
      puts "#{i}"
      for item in $dramCommandList
        puts "command = #{item["command"]} row = #{item["row"]} bank = #{item["bank"]} col = #{item["col"]} expectedDRAMTime = #{item["expectedDRAMTime"]}"
      end
      puts ""
=end
    end
  end


  def executeDRAMCommand(dramCommand, bank, row, column)
    if dramCommand == "ACT"
      if $debug == false
        $outfile.syswrite "%5d %5s %2d %5d\n" % [$CpuClock, dramCommand, bank, row]
      
      else
        $outfile.syswrite "%12d %12d %14s %7d %7d %8d %17s %25d\n" % \
        [$CpuClock, $DRAMClock, dramCommand, bank, row, column, $dramCommandList.first["CPURequest"]["inst"], $dramCommandList.first["CPURequest"]["cpuTime"]]
      end

      $openPage[bank] = row

    elsif dramCommand == "PRE"
      if $debug == false
        $outfile.syswrite "%5d %5s %2d\n" % [$CpuClock, dramCommand, bank]

      else
        $outfile.syswrite "%12d %12d %14s %7d %7d %8d %17s %25d\n" % \
        [$CpuClock, $DRAMClock, dramCommand, bank, row, column, $dramCommandList.first["CPURequest"]["inst"], $dramCommandList.first["CPURequest"]["cpuTime"]]
      end

      $openPage[bank] = nil

    elsif dramCommand == "RD"
      if $debug == false
        $outfile.syswrite "%5d %5s %2d %5d\n" % [$CpuClock, dramCommand, bank, column]

      else
        $outfile.syswrite "%12d %12d %14s %7d %7d %8d %17s %25d\n" % \
        [$CpuClock, $DRAMClock, dramCommand, bank, row, column, $dramCommandList.first["CPURequest"]["inst"], $dramCommandList.first["CPURequest"]["cpuTime"]]
      end

    elsif dramCommand == "RDAP"
      if $debug == false
        $outfile.syswrite "%5d %5s %2d %5d\n" % [$CpuClock, dramCommand, bank, column]
      
      else
        $outfile.syswrite "%12d %12d %14s %7d %7d %8d %17s %25d\n" % \
        [$CpuClock, $DRAMClock, dramCommand, bank, row, column, $dramCommandList.first["CPURequest"]["inst"], $dramCommandList.first["CPURequest"]["cpuTime"]]
      end

      $openPage[bank] = nil

    elsif dramCommand == "WR"
      if $debug == false
        $outfile.syswrite "%5d %5s %2d %5d\n" % [$CpuClock, dramCommand, bank, column]

      else
        $outfile.syswrite "%12d %12d %14s %7d %7d %8d %17s %25d\n" % \
        [$CpuClock, $DRAMClock, dramCommand, bank, row, column, $dramCommandList.first["CPURequest"]["inst"], $dramCommandList.first["CPURequest"]["cpuTime"]]
      end

    elsif dramCommand == "WRAP"
      if $debug == false
        $outfile.syswrite "%5d %5s %2d %5d\n" % [$CpuClock, dramCommand, bank, column]

      else
        $outfile.syswrite "%12d %12d %14s %7d %7d %8d %17s %25d\n" % \
        [$CpuClock, $DRAMClock, dramCommand, bank, row, column, $dramCommandList.first["CPURequest"]["inst"], $dramCommandList.first["CPURequest"]["cpuTime"]]
      end

      $openPage[bank] = nil

    elsif dramCommand == "REF"
      $outfile.syswrite "%10d %5s" % [$CpuClock, dramCommand]
      $openPage[bank] = nil
    end
  end
end


#this is like main, calling each function above to carry out all DRAM memory request
if ARGV.size > 3 || ARGV.size < 1
  puts "usage: #{$0} <inputFile.txt> <-d>"
  puts "optional -d for debug"
  exit
end

simulate = ParseCpuRequests.new
inputFilename = ARGV[0]

if ARGV[1]
  $debug = true
  puts "running in debug mode"
else
  $debug = false
end

outputFilename = inputFilename.split(".")[0] + "Log.txt"
$file = File.open(inputFilename,"r")
$outfile = File.new(outputFilename, "w")

if $debug == true
  $outfile.syswrite "%12s %12s %14s %7s %7s %8s %17s %25s\n" % ["CPU Time", "DRAM Time", "DRAM Command", "Bank", "Row", "Column", "CPU Instruction", "CPU time added to queue"]
end

simulate.simulateDRAMMemController
$outfile.close
