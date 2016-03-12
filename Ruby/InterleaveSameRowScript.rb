#!/usr/bin/ruby

class InterleaveSameRowScript

def createNums
  $cpu = 10
  $mix = 0
  $prevRow = 0
  $prevBank = 0
  for i in 1..3

    $cpu = $cpu + rand(1..10)
    instruc = rand(3)

    $row = rand((2**15)).to_s(2).rjust(15,'0')
    $bank = rand((2**3)).to_s(2).rjust(3,'0')
    $col = rand((2**11)).to_s(2).rjust(11,'0')
    $byte = rand((2**3)).to_s(2).rjust(3,'0')

    puts "row #{$row} bank #{$bank} col #{$col} byte #{$byte}"
    different = ($row+$bank+$col+$byte).to_i(2).to_s(16)
    different = different.rjust(8,'0')

    $prevRow = $row
    $prevBank = $bank

    if instruc == 1
      $outfile.syswrite "0x#{different} WRITE #{$cpu}\n"
      puts "row #{$row.to_i(2)} bank #{$bank.to_i(2)} col #{$col.to_i(2)} byte #{$byte.to_i(2)}\n"
    elsif instruc == 2 # or instruc == 5 or instruc == 6
      $outfile.syswrite "0x#{different} READ #{$cpu}\n"
      puts "row #{$row.to_i(2)} bank #{$bank.to_i(2)} col #{$col.to_i(2)} byte #{$byte.to_i(2)}\n"
    else
      $outfile.syswrite "0x#{different} IFETCH #{$cpu}\n"
      puts "row #{$row.to_i(2)} bank #{$bank.to_i(2)} col #{$col.to_i(2)} byte #{$byte.to_i(2)}\n"
    end


    $cpu = $cpu + rand(1..10)
    instruc = rand(3)

    $row = rand((2**15)).to_s(2).rjust(15,'0')
    $bank = rand((2**3)).to_s(2).rjust(3,'0')
    $col = rand((2**11)).to_s(2).rjust(11,'0')
    $byte = rand((2**3)).to_s(2).rjust(3,'0')

    puts "row #{$row} bank #{$bank} col #{$col} byte #{$byte}"
    different = ($row+$bank+$col+$byte).to_i(2).to_s(16)
    different = different.rjust(8,'0')

        if instruc == 1
          $outfile.syswrite "0x#{different} WRITE #{$cpu}\n"
          puts "row #{$row.to_i(2)} bank #{$bank.to_i(2)} col #{$col.to_i(2)} byte #{$byte.to_i(2)}\n"
        elsif instruc == 2 # or instruc == 5 or instruc == 6
          $outfile.syswrite "0x#{different} READ #{$cpu}\n"
          puts "row #{$row.to_i(2)} bank #{$bank.to_i(2)} col #{$col.to_i(2)} byte #{$byte.to_i(2)}\n"
        else
          $outfile.syswrite "0x#{different} IFETCH #{$cpu}\n"
          puts "row #{$row.to_i(2)} bank #{$bank.to_i(2)} col #{$col.to_i(2)} byte #{$byte.to_i(2)}\n"
        end

    $cpu = $cpu + rand(1..10)
    instruc = rand(3)

    puts "row #{$prevRow} bank #{$prevBank} col #{$col} byte #{$byte}"
    different = ($prevRow+$prevBank+$col+$byte).to_i(2).to_s(16)
    different = different.rjust(8,'0')

        if instruc == 1
          $outfile.syswrite "0x#{different} WRITE #{$cpu}\n"
          puts "row #{$prevRow.to_i(2)} bank #{$prevBank.to_i(2)} col #{$col.to_i(2)} byte #{$byte.to_i(2)}\n"
        elsif instruc == 2 # or instruc == 5 or instruc == 6
          $outfile.syswrite "0x#{different} READ #{$cpu}\n"
          puts "row #{$prevRow.to_i(2)} bank #{$prevBank.to_i(2)} col #{$col.to_i(2)} byte #{$byte.to_i(2)}\n"
        else
          $outfile.syswrite "0x#{different} IFETCH #{$cpu}\n"
          puts "row #{$prevRow.to_i(2)} bank #{$prevBank.to_i(2)} col #{$col.to_i(2)} byte #{$byte.to_i(2)}\n"
        end


  end
end
end



simulate = InterleaveSameRow.new
$outfile = File.new("testInterleaveSameRow.txt", "w")
simulate.createNums
$outfile.close
