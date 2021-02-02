#!/bin/bash

### THIS SHIT WORKS DO NOT FUCK WITH IT

n=`wc -l < /ansible/loadtest/Clients_Config`
A=1

Factorial () 
{
	factorial=1
	for(( i=1; i<=$1; i++ ))
	do
		factorial=$[ $factorial * $i ]
	done
	echo $factorial
}

nf=$(Factorial ${n})


R_Loop ()
{
	for(( rn=1; rn<=$n; rn++ ))
	do
		rf=$(Factorial ${rn})
		rmn=$[ $n - $rn ]
		rmnf=$(Factorial ${rmn})
		c=$(( nf / $(( rf * rmnf ))))

		C_Loop $c
	done
}

C_Loop () 
{
	i=0
	while [ $i -lt $1 ]
	do
		numoffor=0
		A=1
		IPs=()
		funct
	done 
}


funct ()
{
	
	if [ $rn == 2 ]	
	then
		g=''
		for((w=1; w <= `wc -l < /ansible/loadtest/Clients_Config`; w++))
		do
			g+=$w' '
		done

		set -- $g
		for a; do
			shift
			for b; do
				array=`printf "%s %s\n" "$a" "$b"`
				arraytest=${array//[[:blank:]]/}
			
				printf "\n\n" >> /etc/ansible/hosts
				echo "[Client_"$rn"_Set"$i"]" >> /etc/ansible/hosts
									
				for((s=0; s<`echo -n $arraytest | wc -c`; s++))
				do
					echo `sed -n ${arraytest:${s}:1}p /ansible/loadtest/Clients_Config` >> /etc/ansible/hosts

				done
				i=$[ $i + 1]
			done
		done

	elif [ $rn != 1 ]
	then
		k=0
		for (( j=1; j<=$n; j++ ))
		do
			if [ $A != $rn ]
			then
				A=$[ $A + 1 ]
				numoffor=$[ $numoffor + 1 ]
				funct
			else
				q=$n-$j
				qf=$(Factorial ${q})
				qmr=$(( q - 2 ))
				qmrf=$(Factorial ${qmr})
				nrf=2
				newc=$(( qf / $(( $nrf * $qmrf ))))

				if [ $newc != 0 ]
				then
					create_sort_list $q
				fi
			fi
		done
	else
		printf "\n\n" >> /etc/ansible/hosts
		echo "[Clients_All]" >> /etc/ansible/hosts
		for((f=1; f <= `wc -l < /ansible/loadtest/Clients_Config`; f++))
		do 
			echo `sed -n ${f}p /ansible/loadtest/Clients_Config` >> /etc/ansible/hosts
		i=$[ $i + 1 ]
		done
		i=$[ $i + 1]
	fi
}




create_sort_list ()
{
	g=''
	for(( d=$numoffor+$k; $d<=$n; d++ ))
	do
		g+=' '$d
	done
	k=$[$k + 1]
		
	t=$j
	set -- $g
	for a;
	do
		shift
		for b;
		do
			if [ $numoffor != 2 ]
			then
				if [ $[$a - $j] > 2 ]
				then 
					for((u=$j+1; u<$a; u++))
					do
						if [ `echo -n "$t" | wc -c` -lt $[$[$rn - 2] * 2 - 1] ]
						then
							t+=' '$u
						fi
						if [ $[$[$a - $j] + 1] != $n ]
						then
							if [ `echo -n "$t" | wc -c` == $[$[$rn -2] *2 -1] ]
							then
								array=`printf "%s %s %s\n" "$t" "$a" "$b"`
								arraytest=${array//[[:blank:]]/}

								printf "\n\n" >> /etc/ansible/hosts
								echo "[Client_"$rn"_Set"$i"]" >> /etc/ansible/hosts
									
								for((s=0; s<`echo -n $arraytest | wc -c`; s++))
								do
									echo `sed -n ${arraytest:${s}:1}p /ansible/loadtest/Clients_Config` >> /etc/ansible/hosts
								done

							fi
						fi
						if [ `echo -n "$t" | wc -c` == $[$[$rn - 2] * 2 - 1] ]
						then
							t="${t::-2}"
						fi
							i=$[$i + 1]
					done
				fi
			else
				array=`printf "%s %s %s\n" "$t" "$a" "$b"`
				arraytest=${array//[[:blank:]]/}

				printf "\n\n" >> /etc/ansible/hosts
				echo "[Client_"$rn"_Set"$i"]" >> /etc/ansible/hosts
									
				for((s=0; s<`echo -n $arraytest | wc -c`; s++))
				do
					echo `sed -n ${arraytest:${s}:1}p /ansible/loadtest/Clients_Config` >> /etc/ansible/hosts
				done

				t=$j
				i=$[$i + 1]
			fi
			t=$j
		done
	done	
}


R_Loop
