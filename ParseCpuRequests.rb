#!/usr/bin/ruby

class ParseCpuRequests
    @request = Hash.new
    $fileRequest = Array.new
    $CpuClock = 0
    $DRAMClock = 0
    $Buffer = Array.new

    #loads all each line from the external file into an array called $fileRequest
    def getAllRequestIntoQueue(textfile)

      memory_requests = IO.readlines(textfile)
        memory_requests.each do |i|
          setValues(i)
        end
        end
    #parses each line into row
    def setValues(in_line)

      hexAddress = in_line.sub(/0x/, '').split(/\W+/)[0].to_i(16).to_s(2).reverse

      #parse instruction into a hash: row,bank,col,instruction,cpuTime
      $fileRequest << {
                  "row" => hexAddress.split(//)[14..31].join('').reverse.to_i(2),
                  "bank" => hexAddress.split(//)[11..13].join('').reverse.to_i(2),
                  "col" => hexAddress.split(//)[0..10].join('').reverse.to_i(2),
                  "inst" => in_line.split(/\W+/)[1],
                  "cpuTime" => in_line.split(/\W+/)[2].to_i
                  }
    end

    #displays each key:value pairs from the hash
    def getAllRequest
      $fileRequest.each do |i|
        puts i.inspect
      end
    end


  def simulateDRAMMemController

    while (!$fileRequest.empty?() or !$Buffer.empty?() ) do
        #cpu clock
        $CpuClock = $CpuClock + 1

        #only loads the Memory Controller buffer when it's less than 16 and proper CPU time.
        if(!$fileRequest.empty?())
          if(($Buffer.size() < 16) && ($fileRequest.first["cpuTime"] == $CpuClock))
              $Buffer << $fileRequest.shift
              puts $fileRequest.first.inspect
              puts $fileRequest.last.inspect

          end
        end

        #the buffers finishes one Memory request at every 200 CPU cycles (4x50 = 200)
        if(($CpuClock%4 == 0) && !$Buffer.empty?())
          $DRAMClock = $DRAMClock + 1
          #first command will take 50 DRAM cycles
          if($DRAMClock == 50)
            $Buffer.shift
            $DRAMClock = 0
          end
        end
        puts "CPU #{$CpuClock} Buffer #{$Buffer.last} BufferSize #{$Buffer.size()} DClock #{$DRAMClock}\n "
    end #while loop
  end
end

#this is like main, calling each function above to carry out all DRAM memroy request
simulate = ParseCpuRequests.new
simulate.getAllRequestIntoQueue("CPURequest.txt")
simulate.getAllRequest
simulate.simulateDRAMMemController
