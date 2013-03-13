! voidccc created 20120913

! 本文件编译方法
! as86 -0 -a -o boot.o boot.s
! ld86 -0 -s -o boot boot.o

! 说明

! 这是512K的引导扇区，做了如下的工作:
! 1 使用BIOS的0x13中断，读取真正内核到内存
! 2 将内核移动到内存开始位置
! 3 设置保护模式下的初始GDT/IDT
! 4 切换到保护模式
! 5 跳转到内核开始位置执行
!mov cx,#0x2000 here need modify

BOOTSEG = 0x07c0 
SYSSEG = 0x1000         !内核先被加载到的位置
SYSLEN = 17             !内核占用的磁盘扇区数，在使用int 13读取内核时用到
entry start             !入口点
start:
    jmpi go,#BOOTSEG    !段间跳转到
!BIOS已经将本程序加载到0x07c0的位置，目前是在实模式下，启动时段寄存器的缺省值是00，所以这句实际还是跳转到go，0的位置，同时段间跳转会修改CS和IP的值，这句执行完后，CS被设置为0x07c0，IP被设置为go
go:
    mov ax,cs           !让DS和SS都指向0x07c0段，因为段寄存器只能接受寄存器的
    mov ds,ax
    mov ss,ax
    mov sp,#0x400
!使用BIOS中断调用加载内核代码到0x10000处,BIOS的0x13中断具体使用方式此处不做深究。
!只要知道实模式下初始的中断向量表是在跳转到0x07c0之前，已经由BIOS设置好就行。
load_system:
    mov dx,#0x0000
    mov cx,#0x0002
    mov ax,#SYSSEG
    mov es,ax
    xor bx,bx           ! 清空bx，ES:BX(0x10000:0x0000)是读入缓冲区位置
    mov ax,#0x200+SYSLEN
    int 0x13
    jnc ok_load         !若没有发生错误则跳转继续运行，否则死循环
die: jmp die
ok_load:
    cli                 !关闭中断，之所以要关闭中断，是因为此时已经将内核加载完毕，而加载内核是需要使用BIOS提供的0x13中断的，所以在加载完内核前不能关闭中断。而后续要转入保护模式并且使用多任务，在内核完全准备好后续操作前，要将中断关闭。否则中断会破坏内核的初始化。后续再开启多任务时，会再次开启中断。
    mov ax,#SYSSEG      !为rep指令做准备，把要内核要开始移动的位置，放入DS:SI,目的地位置放入ES:DI，移动次数放入cx，cx是移动次数4096(0x1000转换为10进制)次
    mov ds,ax
    xor ax,ax
    mov es,ax
    mov cx,#0x2000
    sub si,si
    sub di,di
    rep
    movw                !每次移动一个字
!加载IDT和GDT基地址寄存器IDTR和GDTR
!因为刚使用了ds，现在要先回复ds
    mov ax,#BOOTSEG
    mov ds,ax
    lidt idt_48         !加载idt，给保护模式用的，48位
    lgdt gdt_48         !加载gdt，给保护模式用的，48位

!设置CR0中的PE位，进入保护模式
    mov ax,#0x0001
    lmsw ax             !将ax放入CR0
!虽然执行LMSW指令以后切换到了保护模式，但该指令规定其后必须紧随一条段间跳转指令以
!刷新CPU的指令缓冲队列。因此在LMSW指令后，CPU还是继续执行下一条指令
!此处0,8已经是保护模式的地址，8是选择符，0是偏移地址
!跳转到段选择符是8，偏移0的地址处,段选择符8转化为16位2进制为
!0000000000001        0          00
!|--描述符索引--|--GDT/LDT--|--特权级--|
!其中0为GDT 1为LDT
!其中00为特权级0 11为特权级3
!其中描述符索引1是CS段选择符，可详见下面gdt的定义
!jmpi 有副作用，会设置CS的值
    jmpi 0,8   

!下面是GDT的内容，3个段描述符，
!第一个不用，第2个是代码段，第三个是数据段  
gdt:
!段描述符0，不用
    .word 0,0,0,0
!段描述符1,
!0x07FF十进制是2047，段限长，
!0x0000 段基地址，
!0x9A00 代码段，可读可执行
!0x00c0 段属性颗粒度4k      
    .word 0x07FF,0x0000,0x9A00,0x00c0
!段描述符2,
!0x07FF十进制是2047，段限长，
!0x0000 段基地址，
!0x9200 数据段，可读可写
!0x00c0 段属性颗粒度4k
    .word 0x07FF,0x0000,0x9200,0x00c0
!??
!下面的数据用于存放到IDTR和GDTR里
!IDTR |---32位表基地址---|--16位表长度--|
!GDTR |---32位表基地址---|--16位表长度--|
!word. 16位长度,32位基地址
idt_48:
    .word 0,0,0
gdt_48:
    .word 0x7ff,0x7c00+gdt,0

!引导扇区的标志
.org 510
    .word 0xAA55
