#!/usr/bin/ruby

class Create

def createNums
  $cpu = 10
  for i in 1..20

    random_string = rand((2**32))
    row_string = (rand(2**15))
    bank_string = (rand(2**3))
    col_string = (rand(2**11))
    byte_string = (rand(2**3))


    row_string = row_string.to_s(2).rjust(15,'0')
    bank_string = bank_string.to_s(2).rjust(3,'0')
    col_string = col_string.to_s(2).rjust(11,'0')
    byte_string = byte_string.to_s(2).rjust(3,'0')

    temp = (row_string+bank_string+col_string+byte_string).to_i(2).to_s(16)
    temp = temp.rjust(8,'0')
    #puts temp
#    puts "\n"
    #puts random_string
    random_string = random_string.to_s(16).rjust(8,'0')



    mix = rand(3)

  if mix == 1
        #puts "entered different bank"
        #$outfile.syswrite "Same Row - Different Bank\n"
        for j in 1..2
            $cpu = $cpu + rand(100)
          instruc = rand(3)
          bank_string = (rand(2**3))
          bank_string = bank_string.to_s(2).rjust(3,'0')

            temp = (row_string+bank_string+col_string+byte_string).to_i(2).to_s(16)
            temp = temp.rjust(8,'0')
            if instruc == 1
              $outfile.syswrite "0x#{temp} WRITE #{$cpu}\n"
            elsif instruc == 2 # or instruc == 5 or instruc == 6
              $outfile.syswrite "0x#{temp} READ #{$cpu}\n"
            else
              $outfile.syswrite "0x#{temp} IFETCH #{$cpu}\n"

          #  puts random_string
          end
          puts temp.to_i(16).to_s(2).rjust(32,'0')
        end

    else

      #puts "entered different row"
      #$outfile.syswrite "Differen Row - Same Bank\n"
          for j in 1..2
              $cpu = $cpu + rand(100)
              instruc = rand(3)
              row_string = (rand(2**15))
              row_string = row_string.to_s(2).rjust(15,'0')

              temp = (row_string+bank_string+col_string+byte_string).to_i(2).to_s(16)
              temp = temp.rjust(8,'0')

                temp = (row_string+bank_string+col_string+byte_string).to_i(2).to_s(16)
                temp = temp.rjust(8,'0')

                if instruc == 1 #or instruc == 2 or instruc == 3

                  $outfile.syswrite "0x#{temp} WRITE #{$cpu}\n"
                elsif instruc == 2 #4 or instruc == 5 or instruc == 6
                  $outfile.syswrite "0x#{temp} READ #{$cpu}\n"
                else
                  $outfile.syswrite "0x#{temp} IFETCH #{$cpu}\n"

              #  puts random_string
              end
              puts temp.to_i(16).to_s(2).rjust(32,'0')


          end
      end

  end
end
end

simulate = Create.new
$outfile = File.new("testMixingRowBank.txt", "w")
simulate.createNums
$outfile.close
