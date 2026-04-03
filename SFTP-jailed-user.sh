Sftp -> Είναι ένα πρωτόκολλο πάνω στο ssh file transfer protocol , όπου το συγκεκριμένο πέρα από το Secure shell προσθέτει και ένα Public key (Symmetric cryptography) και την επικοινωνία στην αρχή και ύστερα η το Private key δημιουργείται από τα attributes της κάθε μεταδοσης μεταξύ του server και του χρήστη.

Additionally everythings is encrypted running on top of ssh 
!!!!



I made a user named john at the group sftponly
With passwd - root

Link for youtube video ->
	  CentOS 7 - Setup SFTP with Chroot jail

That will guide me between the steps !

1st step
#At first we need to install the sftp  -> 
    dnf install openssh-server -y

 

By that command we can verify the version of the sftp 
ssh -V

Start the service
   systemctl enable sshd.service
   systemctl start sshd.service

You can enter the sftp ui by that command and select the network you want and select the
Connect automatically by pressing enter to that box 
   nmtui

   netstat -tulpn | grep:22 ( netstat does not work on oracle only ss and we want a space bar between grep and the port)
  

   ss -tulpn | grep :22


   cd /etc/ssh
   ls

   cat sshd_config
   ls
   cat sshd_config.d
    ls
   cat ssh_config
   ls
   pwd

   vi sshd_config
	
	   And here you have 2 solutions to follow :
		At first do :
		
		Subsystem            sftp             internal-sftp
	   
		a. To make settings for group
	   2)    To make settings for user 
	
		And then :
		
		Match Group sftponly
			ChrootDirectory %h
			ForceCommand internal-sftp
			X11Forwarding no 
			AllowTcpForwarding no
	



   systemctl restart sshd.service


   groupadd sftponly
   useradd john -g sftponly -s /bin/false



# Sets or changes the password for the user "john" that is going to be "root"
passwd john

# Creates a directory named "datadir" inside /home/john
mkdir /home/john/datadir

# Changes ownership of /home/john directory to user "root"
chown root /home/john

# Sets permissions of /home/john to 755 (owner: full access, group/others: read & execute)
chmod 755 /home/john

# Changes ownership of /home/john/datadir to user "john"
chown john /home/john/datadir

# Sets permissions of /home/john/datadir to 755 (owner: full access, others: read & execute)
chmod 755 /home/john/datadir


Here we have an issue with SELinux and that’s why  setted that flag as active
   setsebool -P ssh_chroot_rw_homedirs on


 in order to login to the user chroot john within the localhost 
   sftp john@localhost 

These commands configure directory ownership and permissions, typically to set up a secure chroot jail for a user (e.g., for SFTP).

chown root /home/john
Change owner of /home/john to root
	• The directory is now owned by root, not john.
	• This is required for chroot to work — sshd/chroot will refuse to jail a user if they own their own jail root. It's a security requirement to prevent escape.

chmod 755 /home/john
Set permissions on /home/john
Who	Permission
Owner (root)	rwx — read, write, execute
Group	r-x — read, execute
Others	r-x — read, execute
	• Root can write to it; everyone else can only read/traverse it.
	• John cannot write to his own jail root — again, intentional for chroot security.

chown john /home/john/datadir
Give john ownership of his data subdirectory
	• Since john can't write to /home/john (owned by root), he needs his own writable subdirectory inside the jail.
	• This gives him a place to actually store/upload files.

chmod 755 /home/john/datadir
Set permissions on john's data directory
Who	Permission
Owner (john)	rwx — full access
Group	r-x — read/traverse only
Others	r-x — read/traverse only
	• John has full read/write/execute inside datadir.
	• Others can browse but not modify.

The Big Picture
/home/john/          ← owned by root, chmod 755 (chroot anchor — must be root-owned)
└── datadir/         ← owned by john, chmod 755 (john's actual working space)
This pattern is the standard way to:
	1. Satisfy chroot's security requirement (root owns the jail root)
	2. Still give the user a writable space inside the jail via a subdirectory
