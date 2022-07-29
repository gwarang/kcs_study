#!/bin/bash
# 변수 선언
temp=$(mktemp -t test.XXX)      # 함수내에서 결과를 파일로 저장하기위해
ans=$(mktemp -t test.XXX)       # 메뉴에서 선택한 번호담기위한 변수
image=$(mktemp -t test.XXX)     # 템플릿 이미지를 담기위한 변수
vmname=$(mktemp -t test.XXX)    # 가상머신 이름 담기위한 변수
flavor=$(mktemp -t test.XXX)    # CPU/RAM 세트인 flavor 정보 담기위한 변수
r_vmname=$(mktemp -t test.XXX)	# 삭제할 vm이름을 담기위한 변수

# 함수 선언
# 가상머신 리스트 출력 함수
vmlist(){
        virsh list --all > $temp
        dialog --textbox $temp 20 50
}

# 가상 네트워크 리스트 출력 함수
vmnetlist(){
        virsh net-list --all > $temp
        dialog --textbox $temp 20 50
}

# 가상머신 생성 함수
vmcreation(){
	dialog --title "이미지 선택하기" --radiolist "베이스 이미지를 아래에서 선택하세요" 15 50 5 "CentOS7" "센토스 7 베이스 이미지" ON "Ubuntu" "우분투 20.04 베이스 이미지" OFF "RHEL" "레드햇 엔터프라이즈 리눅스 8.0" OFF 2> $image

	vmimage=$(cat $image)
	case $vmimage in
	CentOS7)
		os=/cloud/CentOS7-Base.qcow2 ;;
	Ubuntu)
		os=/cloud/Ubuntu20-Base.qcow2 ;;
	RHEL)
		os=/cloud/RHEL-Base.qcow2 ;;
	*)
		dialog --mgsbox "잘못된 선택입니다" 10 40 ;;
	esac
	
	# OS 선택이 정상처리라면 인스턴스 이름 입력하기로 이동
	if [ $? -eq 0 ]
	then
		dialog --title "인스턴스 이름" --inputbox "인스턴스의 이름을 입력하세요 : " 40 50 2> $vmname
		
		# 선택된 이름 이용하여 Base 이미지로부터 새로운 볼륨 생성
		name=$(cat $vmname)
		cp $os /cloud/${name}.qcow2
	
		# 종료 코드가 0인 경우 flavor 선택으로 이동하기
		if [ $? -eq 0 ]
		then
			dialog --title "스펙 선택" --radiolist "필요한 자원을 선택하세요" 15 50 5 "m1.small" "가상 CPU 1개, 메모리 1GB" ON "m1.medium" "가상 CPU 2개, 2GB" OFF "m1.large" "가상 CPU 4개, 메모리 8GB" OFF 2> $flavor

			# flavor 에 따라 cpu 개수, 메모리 사이즈 입력
			spec=$(cat $flavor)
			case $spec in
			m1.small)
				vcpus="1"
				ram="1024"
				dialog --msgbox "CPU : ${vcpus}core(s), RAM: ${ram}MB" 10 50 ;; 
			m1.medium)
				vcpus="2"
				ram="2048"
				dialog --msgbox "CPU : ${vcpus}core(s), RAM: ${ram}MB" 10 50 ;; 
			m1.large)
				vcpus="4"
				ram="8192"
				dialog --msgbox "CPU : ${vcpus}core(s), RAM: ${ram}MB" 10 50 ;; 
			esac

			# 종료코드가 0(OK)인 경우 설치 진행
			if [ $? -eq 0 ]
			then
				virt-install --name $name --vcpus $vcpus --ram $ram --disk /cloud/${name}.qcow2 --import --network network:default,model=virtio --os-type linux --os-variant rhel7.0 --noautoconsole > /dev/null
			fi
				dialog --msgbox "설치가 시작되었습니다" 10 50
		fi
	
	fi


}

vmremove(){
	remove_list=""
	vmlist=$(virsh list --all | grep -v Name | gawk '{print $2}' | sed '/^$/d')
	i=1

	for vm in $vmlist
	do
		if [ $i -eq 1 ]
		then
			remove_list="${vm} '${i}번' ON"
			i=$[ $i + 1 ]
		else
			remove_list="${remove_list} ${vm} '${i}번' OFF"
			i=$[ $i + 1 ]
		fi
	done

	i=$[ $i + 3 ]

	dialog --title "가상머신 삭제" --radiolist "삭제할 가상 머신을 선택하세요" 15 50 $i $remove_list 2> $r_vmname

	if [ $? -eq 0 ]
	then

		dialog --title "삭제 확인" --yesno "삭제하시겠습니까?" 10 20
		
		if [ $? -eq 0 ]
		then
			t_vmname=$(cat $r_vmname)
			virsh destroy ${t_vmname}
			virsh undefine ${t_vmname} --remove-all-storage
		fi
	fi
}

# 메인코드
while [ 1 ]
do
        # 메인메뉴 출력하기
        dialog --menu "KVM 관리 시스템" 20 40 8 1 "가상머신 리스트" 2 "가상 네트워크 리스트" 3 "가상머신 생성" 4 "가상머신 삭제"  0 "종료" 2> $ans

        # 종료코드 확인하여 cancel 이면 프로그램 종료
        if [ $? -eq 1 ]
        then
                break
        fi

        selection=$(cat $ans)
        case $selection in
        1)
                vmlist ;;
        2)
                vmnetlist ;;
        3)
                vmcreation ;;
	4)
		vmremove ;;
        0)
                break ;;
        *)
                dialog --msgbox "잘못된 번호 선택됨" 10 40
        esac
done

# 종료전 임시파일 삭제하기
rm -rf $temp 2> /dev/null
rm -rf $ans 2> /dev/null
rm -rf $image 2> /dev/null
rm -rf $vmnet 2> /dev/null
rm -rf $flavor 2> /dev/null