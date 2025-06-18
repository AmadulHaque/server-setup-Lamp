To completely remove all packages and reset your Ubuntu VPS to a clean state (like a fresh install), you have a few options:

### **Option 1: Reinstall Ubuntu (Recommended)**
The most reliable way is to reinstall Ubuntu from scratch via your VPS provider's control panel (e.g., DigitalOcean, Linode, AWS, etc.). This ensures a completely clean system.

### **Option 2: Remove All Installed Packages Manually**
If you can't reinstall, you can try removing all manually installed packages:

1. **List all installed packages** (excluding default ones):
   ```bash
   comm -23 <(apt-mark showmanual | sort -u) <(gzip -dc /var/log/installer/initial-status.gz | sed -n 's/^Package: //p' | sort -u) > manual-packages.txt
   ```

2. **Remove all manually installed packages**:
   ```bash
   sudo apt-get remove --purge $(cat manual-packages.txt)
   ```

3. **Remove leftover dependencies**:
   ```bash
   sudo apt-get autoremove --purge
   ```

4. **Clean up**:
   ```bash
   sudo apt-get clean
   sudo rm -rf /var/lib/apt/lists/*
   ```

5. **Reset configurations (optional)**:
   ```bash
   sudo find /etc -name "*.dpkg-*" -delete
   sudo find /etc -name "*.ucf-*" -delete
   ```

### **Option 3: Reinstall Ubuntu Core Packages**
If you want to reset core packages to default:

1. **Reinstall all default packages**:
   ```bash
   sudo apt-get install --reinstall ubuntu-minimal ubuntu-standard
   ```

2. **Reset all configs (DANGEROUS, may break system)**:
   ```bash
   sudo dpkg --configure -a
   sudo apt-get install -f
   sudo apt-get --reinstall install $(dpkg -l | grep '^ii' | awk '{print $2}')
   ```

### **Warning:**
- **This may not be 100% clean** like a fresh install.
- **Some packages may break** the system if removed.
- **Backup important data** before proceeding.

### **Best Solution: Reinstall Ubuntu via VPS Provider**
If possible, just **reinstall Ubuntu** from your hosting provider's dashboard—this is the safest and cleanest method.




### **1. Remove Nginx**
#### **Stop Nginx Service**
```bash
sudo systemctl stop nginx
```

#### **Remove Nginx Packages**
```bash
sudo apt-get purge nginx nginx-common nginx-core -y
```

#### **Remove Leftover Config Files & Directories**
```bash
sudo rm -rf /etc/nginx /var/www/html /var/log/nginx
```

#### **Remove Unused Dependencies**
```bash
sudo apt-get autoremove -y
```

---

### **2. Remove MySQL or MariaDB**
#### **Stop MySQL/MariaDB Service**
```bash
sudo systemctl stop mysql    # For MySQL
# OR
sudo systemctl stop mariadb  # For MariaDB
```

#### **Remove MySQL/MariaDB Packages**
**For MySQL:**
```bash
sudo apt-get purge mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* -y
```

**For MariaDB:**
```bash
sudo apt-get purge mariadb-server mariadb-client mariadb-common mariadb-server-core-* mariadb-client-core-* -y
```

#### **Remove Leftover Data & Configs**
```bash
sudo rm -rf /etc/mysql /var/lib/mysql /var/log/mysql
```

#### **Remove Unused Dependencies**
```bash
sudo apt-get autoremove -y
```

---

### **3. Clean Up System**
```bash
sudo apt-get autoclean
sudo apt-get clean
```

---

### **4. Verify Removal**
- Check if Nginx is removed:
  ```bash
  nginx -v  # Should return "command not found"
  ```
- Check if MySQL/MariaDB is removed:
  ```bash
  mysql --version  # Should return "command not found"
  ```

---

### **Optional: Reinstall Later**
If you want to reinstall them later:
```bash
# For Nginx
sudo apt-get install nginx -y

# For MySQL
sudo apt-get install mysql-server -y

# For MariaDB
sudo apt-get install mariadb-server -y
```

---

### **Final Notes**
- **Backup databases** (`/var/lib/mysql`) before deletion if needed.
- If you encounter dependency issues, use:
  ```bash
  sudo apt-get -f install
  ```

Let me know if you need further help! 🚀