#!/usr/bin/env python3
import urllib.request
import urllib.parse
import re
import json
import sys
import http.cookiejar

def get_exams_with_login(username, password):
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    opener.addheaders = [('User-Agent', user_agent)]

    base_url = 'https://sv.dut.udn.vn'
    login_url = f'{base_url}/PageDangNhap.aspx'
    exam_url = f'{base_url}/PageLichTH.aspx'

    try:
        with opener.open(login_url, timeout=10) as response:
            html = response.read().decode('utf-8')
        
        def get_value(name_pattern, source):
            m = re.search(name_pattern, source)
            return m.group(1) if m else ""

        acc_field = get_value(r'name="([^"]*DN_txtAcc)"', html)
        pass_field = get_value(r'name="([^"]*DN_txtPass)"', html)
        btn_field = get_value(r'name="([^"]*QLTH_btnLogin)"', html)
        
        if not acc_field or not pass_field:
             acc_field = get_value(r'name="([^"]*TB_Admin)"', html)
             pass_field = get_value(r'name="([^"]*TB_PW)"', html)
             btn_field = get_value(r'name="([^"]*BT_DangNhap)"', html)

        if not acc_field:
            return {"error": "Could not find login fields on the website."}

        viewstate = get_value(r'id="__VIEWSTATE" value="([^"]*)"', html)
        generator = get_value(r'id="__VIEWSTATEGENERATOR" value="([^"]*)"', html)
        eventvalidation = get_value(r'id="__EVENTVALIDATION" value="([^"]*)"', html)

        login_data = {
            '__VIEWSTATE': viewstate,
            '__VIEWSTATEGENERATOR': generator,
            '__EVENTTARGET': '',
            '__EVENTARGUMENT': '',
            acc_field: username,
            pass_field: password,
            btn_field: 'Đăng nhập'
        }
        
        if eventvalidation:
            login_data['__EVENTVALIDATION'] = eventvalidation
        
        encoded_data = urllib.parse.urlencode(login_data).encode('utf-8')
        with opener.open(login_url, data=encoded_data, timeout=15) as response:
            res_html = response.read().decode('utf-8')
            final_url = response.geturl()
            
        if 'PageDangNhap.aspx' in final_url and (acc_field in res_html or 'DN_txtAcc' in res_html):
            return {"error": "Login failed. Please check your Student ID and Password."}

        with opener.open(exam_url, timeout=15) as response:
            html = response.read().decode('utf-8')

    except Exception as e:
        return {"error": f"Connection error: {str(e)}"}

    table_match = re.search(r'<table[^>]*id="TTKB_GridLT"[^>]*>(.*?)</table>', html, re.IGNORECASE | re.DOTALL)
    if not table_match:
        if "Đăng nhập" in html or "login" in html.lower():
            return {"error": "Session expired or invalid. Please try again."}
        return {"error": "No exam schedule found (you might not have any scheduled exams)."}

    table_content = table_match.group(1)
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', table_content, re.IGNORECASE | re.DOTALL)
    
    exams = []
    for row in rows:
        if 'class="kctHeader"' in row or 'class="GreyBoxCaption"' in row:
            continue

        cols = re.findall(r'<td[^>]*>(.*?)</td>', row, re.IGNORECASE | re.DOTALL)
        if len(cols) < 6: continue
        
        clean_cols = [re.sub(r'<[^>]+>', '', c).strip() for c in cols]
        course_name = clean_cols[2]
        exam_info = clean_cols[5]
        
        if not exam_info: continue
            
        date_match = re.search(r'Ngày:\s*(\d{2}/\d{2}/\d{4})', exam_info)
        # Supports: 13h00, 7h00 (single digit), and 13:00:00
        time_match = re.search(r'Giờ:\s*(\d{1,2}[h:]\d{2})', exam_info)
        room_match = re.search(r'Phòng:\s*([^,]+)', exam_info)
        
        if date_match:
            date_str = date_match.group(1)
            # date_str is dd/mm/yyyy
            d_parts = date_str.split('/')
            if len(d_parts) == 3:
                sort_date = f"{d_parts[2]}{d_parts[1]}{d_parts[0]}"
            else:
                sort_date = "99999999"

            # Normalize time for sorting (e.g., 7h00 -> 07:00, 13:00:00 -> 13:00)
            raw_time = time_match.group(1) if time_match else "00:00"
            norm_time = raw_time.replace('h', ':')
            t_parts = norm_time.split(':')
            if len(t_parts[0]) == 1:
                t_parts[0] = "0" + t_parts[0]
            norm_time = ":".join(t_parts[:2]) # Keep only hh:mm
            
            exams.append({
                "course": course_name,
                "date": date_str,
                "time": raw_time,
                "room": room_match.group(1).strip() if room_match else "N/A",
                "_sort_key": f"{sort_date}_{norm_time}"
            })
            
    # Sort exams chronologically
    exams.sort(key=lambda x: x["_sort_key"])
    
    # Remove sort key before returning
    for e in exams:
        del e["_sort_key"]
            
    return exams

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Missing credentials"}))
        sys.exit(1)
    print(json.dumps(get_exams_with_login(sys.argv[1], sys.argv[2]), ensure_ascii=False))
