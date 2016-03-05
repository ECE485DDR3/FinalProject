#!/usr/bin/ruby

class ParseCpuRequests
  @request = Hash.new
  $fileRequest = Array.new
  $CpuClock = 0
  $DRAMClock = 0
  $count = 0
  $CPUBuffer = Array.new
  $goFetch = 1
  $traceFile = Array.new

  $prevCommands = Array.new
  for i in 0..7
    $prevCommands.push(Hash['ACT' => Float::INFINITY,
                            'PRE' => Float::INFINITY,
                            'RD' => Float::INFINITY,
                            'RDAP' => Float::INFINITY,
                            'WR' => Float::INFINITY,
                            'WRAP' => Float::INFINITY,
                            'REF' => Float::INFINITY])
  end

  #loads all each line from the external file into an array called $fileRequest
  def getOneRequestFromFile
    in_line = $file.gets
    if(in_line != nil)

      check_address = in_line.sub(/0x/, '').split(/\W+/)[0]
      if(check_address.size == 8)

      address = check_address.to_i(16).to_s(2).reverse

      #parse instruction into a hash: row,bank,col,instruction,cpuTime
      $fileRequest << {
                  "row" => address.split(//)[17..31].join('').reverse.to_i(2),
                  "bank" => address.split(//)[14..16].join('').reverse.to_i(2),
                  "col" => address.split(//)[3..13].join('').reverse.to_i(2),
                  "chunk" => address.split(//)[0..2].join('').reverse.to_i(2),
                  "inst" => in_line.split(/\W+/)[1],
                  "cpuTime" => in_line.split(/\W+/)[2].to_i
                  }
    else
      puts "0x#{check_address} is an incorrect address size."
      getOneRequestFromFile
    end
    end
  end

  #displays each key:value pairs from the hash
  def getRequest(index)
    puts $fileRequest[index].inspect

  end

  def simulateDRAMMemController
    begin
      #cpu clock
      $CpuClock = $CpuClock + 1

      if($goFetch == 1 && !$file.eof?())
        getOneRequestFromFile
        $goFetch = 0
      end

      if not $fileRequest.empty?
      #only loads the Memory Controller buffer when it's less or equal to than 16 and proper CPU time.
        if(($CPUBuffer.size() <= 16) && ($fileRequest.first["cpuTime"] == $CpuClock) )#&& !$file.eof?())
          temp = $fileRequest.shift
#          $CPUBuffer << $fileRequest.shift
          if (checkInstruction(temp))
            $CPUBuffer << temp
            $CPUBuffer.last['DRAMCommands'] = getCommandSequence($CPUBuffer.last['inst'])
            puts $CPUBuffer.last
          else
             puts "Instruction Not Queued"
             exit
          end
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
          #first command will take 50 DRAM cycles
          if tryDRAMCommand($CPUBuffer[0]['DRAMCommands'].first, $CPUBuffer[0]['bank'], $CPUBuffer[0]['row'], $CPUBuffer[0]['col']) == true
            #output dram command
            puts "DRAM Command issued: %s   Bank: %d   Row: %d   Column: %d" % [$CPUBuffer[0]['DRAMCommands'].first, $CPUBuffer[0]['bank'], $CPUBuffer[0]['row'], $CPUBuffer[0]['col']]

            #update prevCommands array
            $prevCommands[$CPUBuffer[0]['bank']][$CPUBuffer[0]['DRAMCommands'].first] = 0

            #remove dram command from dram command array
            $CPUBuffer[0]['DRAMCommands'].shift

            if $CPUBuffer[0]['DRAMCommands'].empty?
              #remove item from CPUBuffer (all dram commands for this cpu request have been completed)
              $CPUBuffer.shift
            end
          end
        end
      end

      puts "%4d %3d %2d %s" % [$CpuClock, $DRAMClock, $CPUBuffer.size(), $CPUBuffer.last]
    end while (!$CPUBuffer.empty?() or !$file.eof?())
  end

  def getCommandSequence(requestType)
    commands = Array.new

    if ($CPUBuffer[0]["inst"] == "READ")
      commands.push("ACT")
      commands.push("RDAP")

    elsif ($CPUBuffer[0]["inst"] == "WRITE")
      commands.push("ACT")
      commands.push("WRAP")

    else
      commands.push("ACT")
      commands.push("RDAP")
    end

    return commands

  end

  def checkInstruction(inInstruction)
    #print "#{inInstruction} \n"
    if ((inInstruction["inst"].downcase != "read") &
            (inInstruction["inst"].downcase != "write") &
            (inInstruction["inst"].downcase != "ifetch"))
      puts "#{inInstruction["inst"]} is NOT a valid Instruction"
      return false
    elsif (inInstruction["cpuTime"] < $CpuClock)
      puts "Instruction time is incorrect"
      return false
    else
      return true
    end
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
      if $prevCommands[bank]['ACT'] >= tRC
        return true
      else
        return false
      end

    elsif dramCommand == "RDAP"
      if $prevCommands[bank]['ACT'] >= tRCD
        return true
      else
        return false
      end

    elsif dramCommand == "WRAP"
      if $prevCommands[bank]['ACT'] >= tRCD
        return true
      else
        return false
      end

    else
      puts "command: %s not yet supported" % dramCommand

    end
  end
end


#this is like main, calling each function above to carry out all DRAM memory request
simulate = ParseCpuRequests.new
$file = File.open("CPURequest.txt","r")
simulate.simulateDRAMMemController
