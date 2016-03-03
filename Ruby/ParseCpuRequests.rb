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

  #loads all each line from the external file into an array called $fileRequest
  def getOneRequestFromFile
    in_line = $file.gets
    if(in_line != nil)

      address = in_line.sub(/0x/, '').split(/\W+/)[0].to_i(16).to_s(2).reverse

      #parse instruction into a hash: row,bank,col,instruction,cpuTime
      $fileRequest << {
                  "row" => address.split(//)[14..31].join('').reverse.to_i(2),
                  "bank" => address.split(//)[11..13].join('').reverse.to_i(2),
                  "col" => address.split(//)[0..10].join('').reverse.to_i(2),
                  "inst" => in_line.split(/\W+/)[1],
                  "cpuTime" => in_line.split(/\W+/)[2].to_i
                  }
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

      if(!$fileRequest.empty?())
      #only loads the Memory Controller buffer when it's less or equal to than 16 and proper CPU time.
        if(($CPUBuffer.size() <= 16) && ($fileRequest.first["cpuTime"] == $CpuClock) )#&& !$file.eof?())

          temp = $fileRequest.shift
#          $CPUBuffer << $fileRequest.shift
          if (checkInstruction(temp))
            $CPUBuffer << temp
          else
             puts "Instruction Not Queued"
          end
          $goFetch = 1
        end
      end

      #the buffers finishes one Memory request at every 200 CPU cycles (4x50 = 200)
      if((!$CPUBuffer.empty?()))
        $count = $count + 1

        if($count%4 == 0)
          $DRAMClock = $DRAMClock + 1
        end

        #first command will take 50 DRAM cycles
        if($DRAMClock == 50)
          #getCommandSequence
          $CPUBuffer.shift
          $DRAMClock = 0
        end
      end
      #puts "%4d %4d %3d %2d %s" % [$CpuClock, $count, $DRAMClock, $CPUBuffer.size(), $CPUBuffer.last]
    end while (!$CPUBuffer.empty?() or !$file.eof?())
  end

  def getCommandSequence

    if ($CPUBuffer[0]["inst"] == "READ")
      $CPUBuffer[0].store("command1", "ACT")
      $CPUBuffer[0].store("command2", "RDAP")
      puts $CPUBuffer[0]
    elsif ($CPUBuffer[0]["inst"] == "WRITE")
      $CPUBuffer[0].store("command1", "ACT")
      $CPUBuffer[0].store("command2", "WRAP")
      puts $CPUBuffer[0]
    else
      $CPUBuffer[0].store("command1", "ACT")
      $CPUBuffer[0].store("command2", "RDAP")
      puts $CPUBuffer[0]
    end

  end

  def checkInstruction(inInstruction)
    #print "#{inInstruction} \n"
    if((inInstruction["row"] < 0) or (inInstruction["row"] > 2**15))
      puts "Row is not within the DRAM limit of 0-%d. #{inInstruction["row"]}" % [2**15]
      return false
    elsif ((inInstruction["bank"] < 0) or (inInstruction["bank"] > 2**3))
      puts "Bank is not wihtin the DRAM limit of 0-%d" % [2**3]
      return false
    elsif ((inInstruction["col"] < 0) or (inInstruction["col"] > 2**11))
      puts "Column is not within the DRAM limit of 0- %d" % [2**11]
      return false
    elsif ((inInstruction["inst"].downcase != "read") &
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
end


#this is like main, calling each function above to carry out all DRAM memory request
simulate = ParseCpuRequests.new
$file = File.open("CPURequest.txt","r")
simulate.simulateDRAMMemController
