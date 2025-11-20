#!/bin/bash

# 環境設定
LANG=C

# エラーが出たら終了
set -eU

###----------------------------------------------------------
# 対象ディレクトリ（ポートフォリオ用にマスク済み）
TOTAL_DIR="/data/storage/"
TOTAL_LIST_DIR="/data/storage/monitoring/daily_report/"
TOTAL_LIST_TODAY="Data_Size_$(date +%Y%m%d).txt"
TOTAL_LIST_YESTERDAY="Data_Size_$(date -d '1 day ago' +%Y%m%d).txt"

# メール設定（ポートフォリオ用ダミーアドレス）
MAIL_FROM="noreply@example.com"
MAIL_TO="admin@example.com"
SMTP_SERVER="smtp.example.com"
###----------------------------------------------------------

cd "${TOTAL_DIR}"

# 存在しない場合、昨日のファイルを作成
if [ ! -f "${TOTAL_LIST_DIR}${TOTAL_LIST_YESTERDAY}" ]; then
        touch "${TOTAL_LIST_DIR}${TOTAL_LIST_YESTERDAY}"
fi

# 今日のファイルが存在する場合、ローテーションする
if [ -f "${TOTAL_LIST_DIR}${TOTAL_LIST_TODAY}" ]; then
        mv -f "${TOTAL_LIST_DIR}${TOTAL_LIST_TODAY}" "${TOTAL_LIST_DIR}${TOTAL_LIST_YESTERDAY}"
fi

# 1GB以上のデータを抽出
du -sk * 2>/dev/null | sort -rn | awk '{ printf "%.2f\t%s\n", $1/1024/1024, $2 }' > "${TOTAL_LIST_DIR}${TOTAL_LIST_TODAY}"

#本日と昨日のサイズを比較する関数目を定義
function DIFF_RESULT () {
awk '
FNR==NR {
    prev[$2] = $1;
    next
}

{
    folder = $2
    size_today = $1
    size_yesterday = (folder in prev) ? prev[folder] : 0
    diff = size_today - size_yesterday

    if (diff > 0) {
        printf "%.2fGB %s +%.2fGB\n", size_today, folder, diff
    } else if (diff < 0) {
        printf "%.2fGB %s -%.2fGB\n", size_today, folder, -diff
    } else {
        printf "%.2fGB %s\n", size_today, folder
    }
}
' "${TOTAL_LIST_DIR}${TOTAL_LIST_YESTERDAY}" "${TOTAL_LIST_DIR}${TOTAL_LIST_TODAY}"
}

# 結果をSMTP経由でtelnet経由で送信（メールクライアントがない環境向け）
(
sleep 1
echo "EHLO localhost"
sleep 1
echo "MAIL FROM:<${MAIL_FROM}>"
sleep 1
echo "RCPT TO:<${MAIL_TO}>"
sleep 1
echo "DATA"
sleep 1
echo "Subject: [Daily Report] disk_usage_daily_report $(date +%Y%m%d)"
echo "From: ${MAIL_FROM}"
echo "To: ${MAIL_TO}"
echo

DIFF_RESULT | awk '{printf "%-8s %-30s %s\n", $1, $2, $3}'

echo "."
sleep 1
echo "QUIT"
) | telnet "${SMTP_SERVER}" 25




