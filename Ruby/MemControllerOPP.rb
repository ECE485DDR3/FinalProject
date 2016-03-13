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
                         "cpuTime" => in_line.split(/\W+/)[2].to_i,
                         "state" => "new"
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
      end

      #attempt to add to queue
      if not $fileRequest.empty?
        #only loads the Memory Controller buffer when it's less or equal to than 16 and proper CPU time.
        if(($CPUBuffer.size() <= 16) && ($fileRequest.first["cpuTime"] == $CpuClock))
          $CPUBuffer << $fileRequest.shift
          $goFetch = 1

        #if the queue is empty (nothing being done), we can skip ahead to when an item from the input file will be added to the queue
        elsif $CPUBuffer.size() == 0
          dramSkip = ($fileRequest.first["cpuTime"] - $CpuClock + (($CpuClock - 1) % 4)) / 4     #determine how many dram cycles have gone by
          $CpuClock = $fileRequest.first["cpuTime"]     #update CpuClock
          $DRAMClock += dramSkip     #update DRAMClock
          for bankCommands in $prevCommands      #update number of dram cycles since previous commands
            for command in bankCommands.keys
              bankCommands[command] += dramSkip
            end
          end

          #now correct time to add the request to the queue
          $CPUBuffer << $fileRequest.shift
          $goFetch = 1
        end
      end

      #the buffers finishes one Memory request at every 200 CPU cycles (4x50 = 200)
      if($CpuClock%4 == 0)
        $DRAMClock = $DRAMClock + 1

        #each command in prevCommands array is now 1 DRAM clock older
        for bankCommands in $prevCommands
          for command in bankCommands.keys
            bankCommands[command] += 1
          end
        end

        #only check for dram commands if there are items in the buffer
        if not $CPUBuffer.empty?
          #calculate the dram commands that need to be performed for the next item in the queue
          if $CPUBuffer.first["state"] == "new"
            $CPUBuffer.first["DRAMCommands"] = getCommandSequence($CPUBuffer.first["inst"], $CPUBuffer.first["bank"], $CPUBuffer.first["row"], $CPUBuffer.first["col"])
            $CPUBuffer.first["state"] = "in progress"
          end

          #check if we can do the dram command
          if tryDRAMCommand($CPUBuffer[0]["DRAMCommands"].first, $CPUBuffer[0]["bank"], $CPUBuffer[0]["row"], $CPUBuffer[0]["col"]) == true

            #output dram command
            #puts "DRAM Command issued: %s   Bank: %d   Row: %d   Column: %d" % [$CPUBuffer[0]["DRAMCommands"].first, $CPUBuffer[0]["bank"], $CPUBuffer[0]["row"], $CPUBuffer[0]["col"]]
            executeDRAMCommand($CPUBuffer[0]["DRAMCommands"].first, $CPUBuffer[0]["bank"], $CPUBuffer[0]["row"], $CPUBuffer[0]["col"])

            #update prevCommands array
            $prevCommands[$CPUBuffer[0]["bank"]][$CPUBuffer[0]["DRAMCommands"].first] = 0

            #remove dram command from dram command array
            $CPUBuffer[0]["DRAMCommands"].shift

            if $CPUBuffer[0]["DRAMCommands"].empty?
              #remove item from CPUBuffer (all dram commands for this cpu request have been completed)
              $CPUBuffer.shift
            end
          end
        end
      end
#=begin
    # Testing the ouput
      puts "CpuClock = %d" % $CpuClock
      puts "DRAMClock = %d" % $DRAMClock
      puts "CPUBuffer size = %d" % $CPUBuffer.size()
      puts "Queue = "
      for item in $CPUBuffer.each
        puts "       %s" % item
      end
      puts "fileRequest = #{$fileRequest}"
      puts ""
#=end
    end while (!$CPUBuffer.empty?() or !$fileRequest.empty? or !$file.eof?)
  end

  def getCommandSequence(requestType, bank, row, column)

    puts "Open #{$openPage.inspect} \n type #{requestType}, bank #{bank}, row #{row}, col #{column}"
    commands = Array.new

    if ((requestType == "READ") || (requestType == "IFETCH"))
      if $openPage[bank] == row
        commands.push("RD")

      elsif $openPage[bank] == nil
        commands.push("ACT")
        commands.push("RD")

      elsif $openPage[bank] != row
        commands.push("PRE")
        commands.push("ACT")
        commands.push("RD")
      end

    elsif (requestType == "WRITE")
      if $openPage[bank] == row
        commands.push("WR")

      elsif $openPage[bank] == nil
        commands.push("ACT")
        commands.push("WR")

      elsif $openPage[bank] != row
        commands.push("PRE")
        commands.push("ACT")
        commands.push("WR")
      end
    end

    return commands
  end

  def tryDRAMCommand(dramCommand, bank, row, column)
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

    if dramCommand == "ACT"
      if $prevCommands[bank]["ACT"] < tRC
        return false

    #possible later elsif for tRFC - Refresh to Activate

    elsif $prevCommands[bank]["PRE"] < tRP
      return false

      else
        for interBankAct in $prevCommands.each
          if interBankAct["ACT"] < tRRD
            return false
          end
        end

        return true
    end

    elsif (dramCommand == "RD") || (dramCommand == "RDAP")
      if $prevCommands[bank]["ACT"] < tRCD
        return false

#      elsif $prevCommands[bank]["RD"] < tCCD
#        return false

#      elsif $prevCommands[bank]["WR"] < (tCAS + tCCD + 2 - tCWL)
#        return false

      else

        for intCommand in $prevCommands.each
          if intCommand["WR"] < (tCAS + tCCD + 2 - tCWL)
            return false

          elsif intCommand["RD"] < tCCD
            return false
          end
        end

        return true
      end

    elsif (dramCommand == "WR") || (dramCommand == "WRAP")
      if $prevCommands[bank]["ACT"] < tRCD
        return false

#      elsif $prevCommands[bank]["WR"] < tCCD
#        return false

#      elsif $prevCommands[bank]["RD"] < (tCWL + tBURST + tWTR)
#        return false

      else

        for intCommand in $prevCommands.each
          if intCommand["RD"] < tCWL + tBURST + tWTR
            return false

          elsif intCommand["WR"] < tCCD
            return false
          end
        end

        return true
      end

    elsif dramCommand == "PRE"
      if $prevCommands[bank]["ACT"] < tRAS
        return false

      elsif $prevCommands[bank]["RD"] < tRTP
        return false

      elsif $prevCommands[bank]["WR"] < (tCWL + tBURST + tWR)
        return false

      else
        return true
      end

    else
      puts "Timing for DRAM command [%s] executed at CPU clock [%d] not supported" % [dramCommand, $CpuClock]
      return true
    end
  end

  def executeDRAMCommand(dramCommand, bank, row, column)
    if dramCommand == "ACT"
      $outfile.syswrite "%5d %5s %2d %5d\n" % [$CpuClock, dramCommand, bank, row]
      $openPage[bank] = row

    elsif dramCommand == "PRE"
      $outfile.syswrite "%5d %5s %2d\n" % [$CpuClock, dramCommand, bank]
      $openPage[bank] = nil

    elsif dramCommand == "RD"
      $outfile.syswrite "%5d %5s %2d %5d\n" % [$CpuClock, dramCommand, bank, column]

    elsif dramCommand == "RDAP"
      $outfile.syswrite "%5d %5s %2d %5d\n" % [$CpuClock, dramCommand, bank, column]
      $openPage[bank] = nil

    elsif dramCommand == "WR"
      $outfile.syswrite "%5d %5s %2d %5d\n" % [$CpuClock, dramCommand, bank, column]

    elsif dramCommand == "WRAP"
      $outfile.syswrite "%5d %5s %2d %5d\n" % [$CpuClock, dramCommand, bank, column]
      $openPage[bank] = nil

    elsif dramCommand == "REF"
      $outfile.syswrite "%5s" % [$CpuClock]
      $openPage[bank] = nil
    end
  end
end


#this is like main, calling each function above to carry out all DRAM memory request
if ARGV.size != 1
  puts "usage: #{$0} <inputFile.txt>"
  exit
end

simulate = ParseCpuRequests.new
inputFilename = ARGV[0]
outputFilename = inputFilename.split(".")[0] + "Log.txt"
$file = File.open(inputFilename,"r")
$outfile = File.new(outputFilename, "w")
simulate.simulateDRAMMemController
$outfile.close
