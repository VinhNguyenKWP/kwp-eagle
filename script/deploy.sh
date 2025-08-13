echo "🔁 Pulling latest code..."

cd ~/kwp-kwp_eagle || exit 1
git pull origin main   # lấy code mới nhất từ PC / Server

git pull origin main --rebase

git reset --hard
git pull origin main --rebase

# ./script/deploy/gitpush.sh 

echo "🚀 Restarting service (nếu cần)..."

#ENV
nano ~/kwp-monorepo/kwp_core/settings/.env

#máy ảo
source venv/bin/activate

pip install -r requirements.txt

# MÁY ẢO
.\venv\Scripts\activate

# KWP_CORE EDITABLE
pip install -e D:/Projects/kwp-monorepo

sudo nano /etc/systemd/system/kwp-scheduler-v2.service

# systemctl restart kwp-webhook.service  # nếu có
# hoặc: pkill python && python -m kwp_webhooks.main &

sudo systemctl restart kwp-webhooks.service
sudo systemctl stop kwp-webhooks.service
journalctl -u kwp-webhooks.service -f


sudo systemctl restart kwp-scheduler-v2.service
sudo systemctl stop kwp-scheduler-v2.service
sudo systemctl status kwp-scheduler-v2.service
journalctl -u kwp-scheduler-v2.service -f

#FIX LỖI NGÀY CÔNG
python -m kwp_scheduler.jobs.core_hanet_sync
python -m kwp_scheduler.jobs.employee_attendance_summary


sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo journalctl -u kwp-webhooks.service --since "2 hours ago" | less
sudo journalctl -u kwp-webhooks.service --since "1 days ago" | less
sudo journalctl -u kwp-scheduler-v2.service --since "24 hours ago" | less