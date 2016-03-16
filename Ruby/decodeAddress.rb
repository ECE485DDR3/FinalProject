#!/usr/bin/ruby
if ARGV.size != 1
  puts "usage: #{$0} <inputFile.txt>"
  exit
end

inputFilename = ARGV[0]
$file = File.open(inputFilename,"r")
$fileRequest = Array.new

begin
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
      puts $fileRequest
      $fileRequest.pop
    end
  end
end while not $file.eof?