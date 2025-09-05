# 🚕 Crimson Taxi – Nghề Taxi cho QBCore  

## 1. Giới thiệu  
Crimson Taxi mang đến hệ thống nghề taxi chuyên nghiệp trong **QBCore**, với đầy đủ tính năng:  
- Thuê xe và quản lý xe công ty.  
- Đồng hồ tính cước (Taxi Meter).  
- Nhận và hoàn thành đơn hàng NPC.  
- Đồng bộ dữ liệu biển số, trạng thái thuê và phương tiện.  

---

## 2. Chức năng chính  

### 2.1. Quản lý phương tiện  
- **Xe thuê (Rental Taxi)**  
  - Người chơi có thể thuê xe của công ty.  
  - Trạng thái thuê (đang thuê/trả lại) được đồng bộ giữa server và client.  
  - Xe trả hoặc hết hạn sẽ tự động xóa.  

- **Xe công ty (Boss Vehicles)**  
  - Mua bằng quỹ công ty.  
  - Xe mua sẽ được lưu trong bảng `taxi_owner_vehicles` và đồng bộ tới client.  
  - Chỉ xe có biển số hợp lệ trong cơ sở dữ liệu mới được sử dụng.  

---

### 2.2. Đồng hồ tính cước (Taxi Meter)  
- **ALT (19)**: bật/tắt tính cước.  
- **F9 (56)**: mở/đóng giao diện đồng hồ.  
- Giá cước mặc định theo **100m**, có thể chỉnh trong `Config.MeterPrice`.  
- Chỉ hoạt động khi ngồi trong xe hợp lệ (thuê hoặc boss).  

---

### 2.3. Hệ thống đơn hàng NPC  
- **K (311)**: mở menu nhận đơn, yêu cầu đang ngồi trong xe hợp lệ.  
- Người chơi chỉ nhận được **một đơn duy nhất** tại một thời điểm.  
- Có thể **hủy đơn** trong menu.  
- Hoàn thành đơn để nhận tiền thưởng.  

---

### 2.4. Đồng bộ dữ liệu  
- **Plates** được tải khi:  
  - `onResourceStart`: khi resource khởi động lại.  
  - `QBCore:Server:PlayerLoaded`: khi người chơi đăng nhập.  
- Hệ thống đồng bộ:  
  - Xe công ty (`bossVehicles`).  
  - Biển số hợp lệ (`plates`).  
  - Trạng thái thuê xe (`updateRentalState`).  
  - Danh sách đơn hàng (`syncAll`).  

---

## 3. Bảo mật & kiểm soát  
- Các phím **ALT / F9 / K** đều được kiểm tra điều kiện:  
  - Người chơi phải **ngồi trong xe hợp lệ** (thuê hoặc boss).  
  - Biển số xe phải tồn tại trong cơ sở dữ liệu.  
- Không thể dùng đồng hồ hay nhận đơn khi ngồi xe không hợp lệ.  

---

## 4. Cơ sở dữ liệu  

### 4.1. `taxi_owner_vehicles`  
| id | company_id | model | plate   | price   | label      |  
|----|------------|-------|---------|---------|------------|  
| 9  | CRS        | taxi  | TAXI6578| 200000  | Taxi CRS3  |  

### 4.2. `player_vehicles`  
Xe mua sẽ được insert tự động với thông tin: plate, model, garage = "taxi".  

---

## 5. Quy trình nghiệp vụ  
1. Thuê hoặc lấy xe công ty.  
2. Bật đồng hồ tính cước (ALT) nếu muốn tính tiền.  
3. Nhấn **K** để nhận đơn NPC.  
4. Đón khách → chở tới điểm trả.  
5. Hoàn thành chuyến và nhận tiền.  
6. Trả xe (nếu thuê) hoặc lưu xe (nếu boss).  

---

## 6. Cấu hình  
Trong `config.lua`:  
- `Config.Companies`: danh sách công ty taxi.  
- `Config.MeterPrice.per100m`: giá cước mặc định mỗi 100m.  
- `Config.Keys.toggleUI`: phím mở UI đồng hồ (mặc định F9).  

---

## 7. Ghi chú triển khai  
- Cần **ox_inventory** để hệ thống trả tiền hoạt động chính xác.  
- Đảm bảo tạo bảng **MySQL** trước khi chạy.  
- Khuyến nghị giữ **plates sync** trong `onResourceStart` để tránh lỗi khi reload resource.  
