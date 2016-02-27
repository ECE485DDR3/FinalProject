#!/usr/bin/ruby

class ParseCpuRequests
  @request = Hash.new
  $fileRequest = Array.new
  $CpuClock = 0
  $DRAMClock = 0
  $count = 0
  $Buffer = Array.new
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
        if(($Buffer.size() <= 16) && ($fileRequest.first["cpuTime"] == $CpuClock) )#&& !$file.eof?())

          $Buffer << $fileRequest.shift
          $goFetch = 1
        end
      end

      #the buffers finishes one Memory request at every 200 CPU cycles (4x50 = 200)
      if((!$Buffer.empty?()))
        $count = $count + 1

        if($count%4 == 0)
          $DRAMClock = $DRAMClock + 1
        end

        #first command will take 50 DRAM cycles
        if($DRAMClock == 50)
          $Buffer.shift
          $DRAMClock = 0
        end
      end
      puts "#{$CpuClock} #{$count} #{$DRAMClock} #{$Buffer.size()} #{$Buffer.last}"
    end while (!$Buffer.empty?() or !$file.eof?())
  end
end


#this is like main, calling each function above to carry out all DRAM memory request
simulate = ParseCpuRequests.new
$file = File.open("CPURequest.txt","r")
simulate.simulateDRAMMemController
