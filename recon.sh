#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Simple Banner
echo -e "${BLUE}"
echo "----------------------------------"
echo "      Simple Reconnaissance Tool"
echo "----------------------------------"
echo -e "${NC}"

# Check if domain is provided
if [ -z "$1" ]; then
  echo -e "${RED}[!] Usage: $0 <domain>${NC}"
  exit 1
fi

TARGET=$1
OUTPUT_DIR="recon_$TARGET"
mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}[+] Target: ${YELLOW}$TARGET${NC}"
echo -e "${GREEN}[+] Output saved to ${YELLOW}$OUTPUT_DIR${NC}"
echo

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Improved function to run tool with better error handling
run_tool() {
  local tool_name=$1
  local command=$2
  local output_file=$3

  echo -e "${BLUE}[*] Running $tool_name...${NC}"

  if command_exists "$tool_name"; then
    if eval "$command" > "$OUTPUT_DIR/$output_file" 2>&1; then
      echo -e "${GREEN}[+] $tool_name completed successfully${NC}"
    else
      echo -e "${YELLOW}[!] $tool_name completed with errors${NC}"
    fi
  else
    echo -e "${RED}[-] $tool_name not found (skipping)${NC}"
    echo "$tool_name not installed" > "$OUTPUT_DIR/$output_file"
  fi
  echo
}

# 1. host
run_tool "host" "host \"$TARGET\"" "host.txt"
grep -E 'address|alias|handled' "$OUTPUT_DIR/host.txt" | grep --color=always -i "$TARGET"

# 2. dig
run_tool "dig" "dig \"$TARGET\" any +noall +answer" "dig.txt"
grep -E 'IN\s+(A|MX|TXT|CNAME|NS)' "$OUTPUT_DIR/dig.txt" | grep --color=always -i "$TARGET"

# 3. WhatWeb
run_tool "whatweb" "whatweb -v \"$TARGET\"" "whatweb.txt"
[ -f "$OUTPUT_DIR/whatweb.txt" ] && grep -E 'HTTPServer|Cookies|Country|IP|X-Powered-By' "$OUTPUT_DIR/whatweb.txt" | grep --color=always -i "$TARGET"

# 4. dnsrecon
run_tool "dnsrecon" "dnsrecon -d \"$TARGET\" -a" "dnsrecon.txt"
[ -f "$OUTPUT_DIR/dnsrecon.txt" ] && grep -E 'A\s+|MX\s+|TXT\s+|SOA\s+' "$OUTPUT_DIR/dnsrecon.txt" | grep --color=always -i "$TARGET"

# 5. wafw00f
run_tool "wafw00f" "wafw00f \"http://$TARGET\"" "wafw00f.txt"
if [ -f "$OUTPUT_DIR/wafw00f.txt" ]; then
    echo -e "${YELLOW}[+] WAF Detection Results:${NC}"
    # Show all detection attempts including generic results
    grep -E 'is behind|No WAF detected|Generic Detection results' "$OUTPUT_DIR/wafw00f.txt" | \
    while read -r line; do
        # Colorize different result types
        if [[ "$line" == *"is behind"* ]]; then
            echo -e "${GREEN}  $line${NC}"
        elif [[ "$line" == *"No WAF detected"* ]]; then
            echo -e "${YELLOW}  $line${NC}"
        else
            echo "  $line"
        fi
    done
fi
echo


# 6. subfinder
run_tool "subfinder" "subfinder -d \"$TARGET\" -silent" "subfinder.txt"
if [ -f "$OUTPUT_DIR/subfinder.txt" ]; then
  sub_count=$(wc -l < "$OUTPUT_DIR/subfinder.txt")
  echo -e "${YELLOW}[+] Found ${GREEN}$sub_count${YELLOW} subdomains${NC}"
  head -n 5 "$OUTPUT_DIR/subfinder.txt" | grep --color=always -i "$TARGET"
  [ "$sub_count" -gt 5 ] && echo "... and more (see $OUTPUT_DIR/subfinder.txt)"
fi
echo

# 7. HTTrack (website mirror) - special handling for verbose output
echo -e "${BLUE}[*] Running HTTrack (website mirror)...${NC}"
if command_exists "httrack"; then
  if httrack "http://$TARGET" -O "$OUTPUT_DIR/httrack" "+*.${TARGET}/*" -v -%v > "$OUTPUT_DIR/httrack.log" 2>&1; then
    echo -e "${GREEN}[+] Website successfully mirrored to ${YELLOW}$OUTPUT_DIR/httrack${NC}"
  else
    echo -e "${YELLOW}[!] HTTrack completed with errors (see $OUTPUT_DIR/httrack.log)${NC}"
  fi
else
  echo -e "${RED}[-] HTTrack not found (skipping)${NC}"
  echo "HTTrack not installed" > "$OUTPUT_DIR/httrack.log"
fi
echo

# 8. Wappalyzer (basic curl) with better error handling
echo -e "${BLUE}[*] Checking Wappalyzer (basic tech detection)...${NC}"
if curl -s "https://www.wappalyzer.com/lookup/$TARGET/" > "$OUTPUT_DIR/wappalyzer.txt" 2>&1; then
  if grep -oP '(?<=<strong>).*?(?=</strong>)' "$OUTPUT_DIR/wappalyzer.txt" 2>/dev/null | sort -u | grep --color=always -i -E 'JavaScript|PHP|Python|Ruby|Java|WordPress|Drupal|Joomla|Apache|Nginx|IIS'; then
    echo -e "${GREEN}[+] Wappalyzer results found${NC}"
  else
    echo -e "${YELLOW}[!] No detectable technologies found${NC}"
  fi
else
  echo -e "${RED}[-] Failed to query Wappalyzer${NC}"
fi
echo

# 9. DNSDumpster (basic curl) with better error handling
echo -e "${BLUE}[*] Checking DNSDumpster (basic DNS records)...${NC}"
if curl -s "https://api.hackertarget.com/hostsearch/?q=$TARGET" > "$OUTPUT_DIR/dnsdumpster.txt" 2>&1; then
  if grep -v "^$" "$OUTPUT_DIR/dnsdumpster.txt"; then
    grep -v "^$" "$OUTPUT_DIR/dnsdumpster.txt" | head -n 10 | grep --color=always -i "$TARGET"
    [ $(wc -l < "$OUTPUT_DIR/dnsdumpster.txt") -gt 10 ] && echo "... and more (see $OUTPUT_DIR/dnsdumpster.txt)"
    echo -e "${GREEN}[+] DNS records found${NC}"
  else
    echo -e "${YELLOW}[!] No DNS records found${NC}"
  fi
else
  echo -e "${RED}[-] Failed to query DNSDumpster${NC}"
fi
echo



echo -e "${GREEN}[✔] Recon completed.${NC}"
echo -e "${BLUE}----------------------------------${NC}"
echo -e "${CYAN}Summary for ${YELLOW}$TARGET${NC}"
echo -e "${BLUE}----------------------------------${NC}"

# Display summary
echo -e "${YELLOW}[+] DNS Records:${NC}"
grep -E 'A\s+|MX\s+|TXT\s+' "$OUTPUT_DIR/dig.txt" | awk '{print "  " $0}' | grep --color=always -i "$TARGET"

echo -e "${YELLOW}[+] Web Server:${NC}"
[ -f "$OUTPUT_DIR/whatweb.txt" ] && grep -E 'HTTPServer|X-Powered-By' "$OUTPUT_DIR/whatweb.txt" | awk '{print "  " $0}' | grep --color=always -i "$TARGET"

echo -e "${YELLOW}[+] WAF Detection:${NC}"
[ -f "$OUTPUT_DIR/wafw00f.txt" ] && grep -E 'is behind|No WAF detected|Generic Detection results' "$OUTPUT_DIR/wafw00f.txt" | \
while read -r line; do
    echo "  $line"
done


echo -e "${YELLOW}[+] Subdomains (top 5):${NC}"
[ -f "$OUTPUT_DIR/subfinder.txt" ] && head -n 5 "$OUTPUT_DIR/subfinder.txt" | awk '{print "  " $0}' | grep --color=always -i "$TARGET"

echo -e "${BLUE}----------------------------------${NC}"
echo -e "${GREEN}Full results saved in ${YELLOW}$OUTPUT_DIR/${NC}"
echo -e "${BLUE}Happy Hacking!${NC}"


# Create summary file function
create_summary() {
    echo -e "${BLUE}[*] Creating summary file...${NC}"

    # Initialize summary file with header
    cat << EOF > "$OUTPUT_DIR/summary.txt"
==============================================
            RECON SUMMARY FOR $TARGET
==============================================

Generated on: $(date)

=== HOST COMMAND RESULTS ===
$(grep -E 'address|alias|handled' "$OUTPUT_DIR/host.txt")

=== DIG COMMAND RESULTS ===
$(grep -E 'IN\s+(A|MX|TXT|CNAME|NS|SOA)' "$OUTPUT_DIR/dig.txt")

=== WAF DETECTION RESULTS ===
$(grep -E 'is behind|No WAF detected|Generic Detection results' "$OUTPUT_DIR/wafw00f.txt")

=== SUBDOMAINS ===
Total subdomains found: $(wc -l < "$OUTPUT_DIR/subfinder.txt")

[+] Total subdomains found: $(wc -l < "$OUTPUT_DIR/subfinder.txt")

=== WEB SERVER INFORMATION ===
$([ -f "$OUTPUT_DIR/whatweb.txt" ] && grep -E 'HTTPServer|X-Powered-By' "$OUTPUT_DIR/whatweb.txt")

=== IMPORTANT DNS RECORDS ===
$([ -f "$OUTPUT_DIR/dnsrecon.txt" ] && grep -E 'A\s+|MX\s+|TXT\s+|SOA\s+' "$OUTPUT_DIR/dnsrecon.txt")

==============================================
Full results available in individual files in $OUTPUT_DIR/
==============================================
EOF

    echo -e "${GREEN}[+] Summary file created: ${YELLOW}$OUTPUT_DIR/summary.txt${NC}"
}


create_summary
