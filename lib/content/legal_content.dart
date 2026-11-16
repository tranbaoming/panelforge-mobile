/// Nội dung các trang Điều khoản / Chính sách / Câu hỏi thường gặp hiển thị trong ứng dụng.
///
/// Soạn từ quy định nghiệp vụ của nền tảng PanelForge (Master Spec V2.6: BR-09/16/17 bảo vệ bản quyền,
/// BR-18 nhật ký kiểm toán, BR-32 thống kê độc giả, BR-33 Ví & mở khóa bằng VNĐ, BR-34 ấn bản ngôn ngữ)
/// và đúng những gì ứng dụng + Backend đang làm. Khi pháp chế công bố văn bản chính thức,
/// thay nội dung ở đây (hoặc đặt liên kết trong `services/app_info.dart`).
library;

typedef LegalSection = ({String heading, List<String> body});

class LegalDocument {
  final String id;
  final String title;
  final String updated;
  final String? intro;
  final List<LegalSection> sections;

  const LegalDocument({
    required this.id,
    required this.title,
    required this.updated,
    this.intro,
    required this.sections,
  });
}

const _updated = '15/11/2026';

const termsOfService = LegalDocument(
  id: 'terms',
  title: 'Điều khoản sử dụng',
  updated: _updated,
  intro:
      'Khi tạo tài khoản hoặc sử dụng ứng dụng đọc truyện PanelForge, bạn đồng ý với các điều khoản dưới đây. '
      'Vui lòng đọc kỹ trước khi nạp Ví, mở khóa chương hoặc đăng ký VIP.',
  sections: [
    (
      heading: '1. Dịch vụ',
      body: [
        'PanelForge là nền tảng sản xuất và phát hành truyện tranh. Ứng dụng di động dành cho độc giả: tìm, đọc '
            'các chương đã được Studio phát hành, mở khóa chương trả phí và góp ý bản thảo khi được mời qua mã Review.',
        'Nội dung truyện do các Studio sản xuất và phát hành; PanelForge cung cấp hạ tầng đọc, thanh toán và bảo vệ bản quyền.',
      ],
    ),
    (
      heading: '2. Tài khoản',
      body: [
        'Bạn có thể xem danh sách truyện, chi tiết và danh sách chương mà không cần đăng nhập. '
            'Đọc nội dung chương, tải chương để đọc ngoại tuyến, nạp Ví và mua VIP cần tài khoản đã xác thực email.',
        'Bạn chịu trách nhiệm giữ bí mật mật khẩu và mã xác thực 2 lớp. Thiết bị được đánh dấu tin cậy có thể bỏ qua '
            'bước 2FA trong 30 ngày; bạn có thể xoá thiết bị khỏi danh sách tin cậy bất kỳ lúc nào trong Cài đặt.',
        'Không chia sẻ, mua bán hoặc cho thuê tài khoản. Tài khoản vi phạm có thể bị giới hạn quyền đọc hoặc vô hiệu hóa.',
      ],
    ),
    (
      heading: '3. Chương miễn phí, trả phí và trang xem trước',
      body: [
        'Mỗi chương được phát hành theo từng ấn bản ngôn ngữ (ví dụ Tiếng Việt, English, 日本語). '
            'Loại Miễn phí / Trả phí, giá và số trang xem trước của từng ấn bản do Nhà phát hành (Publisher) quy định.',
        'Với ấn bản trả phí mà bạn chưa mở khóa, bạn được đọc các trang xem trước; các trang còn lại bị làm mờ cho tới khi mở khóa cả chương.',
        'Giá có thể thay đổi theo thời gian. Giá áp dụng là giá hiển thị tại thời điểm bạn xác nhận thanh toán; '
            'máy chủ luôn tính lại giá khi thanh toán.',
      ],
    ),
    (
      heading: '4. Ví PanelForge và thanh toán',
      body: [
        'Mọi giá, số dư Ví và giao dịch tính bằng Việt Nam Đồng (VNĐ). Không có xu, điểm hay đơn vị tiền ảo; không quy đổi ngoại tệ.',
        'Nạp Ví bằng chuyển khoản VietQR vào tài khoản ngân hàng của nền tảng. Tiền chỉ được cộng vào Ví sau khi giao dịch được xác nhận đã nhận; '
            'trong lúc chờ, đơn ở trạng thái Đang chờ và có thể xem trong Lịch sử giao dịch.',
        'Bạn cũng có thể chuyển khoản VietQR trực tiếp để mở khóa một chương hoặc mua VIP mà không cần nạp Ví trước.',
        'Mọi giao dịch được ghi vào sổ giao dịch chỉ-ghi-thêm (không sửa, không xoá) để bảo đảm minh bạch.',
      ],
    ),
    (
      heading: '5. Mở khóa chương',
      body: [
        'Mở khóa bằng Ví trừ đúng giá hiện hành của ấn bản. Nếu số dư không đủ, giao dịch bị từ chối và ứng dụng cho biết số tiền còn thiếu.',
        'Quyền đọc sau khi mở khóa là vĩnh viễn nhưng chỉ cho ấn bản ngôn ngữ đã mua: mua ngôn ngữ nào đọc ngôn ngữ đó. '
            'Mở khóa lại ấn bản đã mua không bị trừ thêm tiền.',
        'Chương đã mở khóa vĩnh viễn có thể tải về để đọc ngoại tuyến trên thiết bị của bạn.',
      ],
    ),
    (
      heading: '6. Gói VIP',
      body: [
        'Gói VIP (tháng hoặc năm) cho phép đọc mọi chương trả phí trong thời hạn gói. Hết hạn, các chương bạn chưa mua riêng trở lại trạng thái khóa.',
        'VIP được kích hoạt ngay khi trả bằng số dư Ví, hoặc khi chuyển khoản VietQR được xác nhận. Gói không tự gia hạn; '
            'bạn chủ động gia hạn trong tab Cửa hàng.',
      ],
    ),
    (
      heading: '7. Hoàn tiền',
      body: [
        'Do nội dung số được cung cấp ngay sau khi mở khóa, các giao dịch mở khóa chương và mua VIP đã hoàn tất không được hoàn tiền, '
            'trừ trường hợp lỗi hệ thống (ví dụ bị trừ tiền nhưng không mở được chương).',
        'Nếu chuyển khoản VietQR nhưng Ví chưa được cộng sau thời gian hợp lý, hoặc gặp lỗi thanh toán, hãy liên hệ hỗ trợ kèm mã đơn trong Lịch sử giao dịch.',
      ],
    ),
    (
      heading: '8. Bản quyền và sử dụng nội dung',
      body: [
        'Truyện và hình ảnh thuộc bản quyền của Studio sáng tác. Bạn chỉ được đọc cho mục đích cá nhân, phi thương mại trong ứng dụng.',
        'Nghiêm cấm sao chép, chụp/quay màn hình để phát tán, tải lại lên nơi khác, bán lại hoặc dùng nội dung để huấn luyện mô hình AI '
            'khi chưa có sự cho phép bằng văn bản của chủ sở hữu.',
        'Bản thảo xem qua mã Review là nội dung chưa phát hành, được phủ hình mờ (watermark) mang danh tính người xem và chỉ có hiệu lực trong thời hạn của lời mời. '
            'Không được chia sẻ mã hoặc nội dung bản thảo.',
      ],
    ),
    (
      heading: '9. Đánh giá truyện',
      body: [
        'Bạn có thể chấm 1–5 sao cho bộ truyện. Đánh giá được dùng để hiển thị điểm trung bình và trong thống kê của Studio. '
            'Không dùng nhiều tài khoản để thao túng đánh giá.',
      ],
    ),
    (
      heading: '10. Xoá tài khoản',
      body: [
        'Bạn có thể xoá tài khoản trong Cài đặt. Tài khoản bị vô hiệu hóa và không đăng nhập được nữa. '
            'Số dư Ví còn lại và quyền đọc đã mua không được hoàn lại hay chuyển sang tài khoản khác.',
        'Lịch sử giao dịch và nhật ký kiểm toán được lưu giữ theo quy định kế toán và đối soát, kể cả sau khi tài khoản bị vô hiệu hóa.',
      ],
    ),
    (
      heading: '11. Thay đổi điều khoản',
      body: [
        'PanelForge có thể cập nhật điều khoản khi tính năng hoặc quy định thay đổi. Ngày cập nhật được ghi ở đầu trang; '
            'tiếp tục sử dụng ứng dụng nghĩa là bạn đồng ý với phiên bản mới.',
      ],
    ),
  ],
);

const privacyNotice = LegalDocument(
  id: 'privacy',
  title: 'Chính sách bảo mật',
  updated: _updated,
  intro: 'Trang này mô tả dữ liệu ứng dụng PanelForge thu thập, lý do sử dụng và quyền của bạn.',
  sections: [
    (
      heading: '1. Dữ liệu tài khoản',
      body: [
        'Email, họ tên, số điện thoại (nếu bạn cung cấp), ảnh đại diện. '
            'Đăng nhập bằng Google nhận email và tên hiển thị từ Google.',
        'Mật khẩu được lưu dưới dạng băm một chiều; PanelForge không xem được mật khẩu của bạn.',
      ],
    ),
    (
      heading: '2. Dữ liệu đọc',
      body: [
        'Lượt đọc chương (gộp trong 30 phút để không đếm trùng), ngôn ngữ ấn bản đã đọc và đánh giá sao bạn gửi.',
        'Studio chỉ thấy số liệu tổng hợp (lượt xem, số độc giả, tỷ lệ đọc hết, phân bố ngôn ngữ, doanh thu); '
            'không thấy danh tính từng độc giả.',
      ],
    ),
    (
      heading: '3. Dữ liệu thanh toán',
      body: [
        'Số dư Ví, các đơn nạp / mở khóa / VIP (số tiền, thời điểm, trạng thái, chương liên quan) và quyền đọc đã mua.',
        'Chuyển khoản thực hiện trong ứng dụng ngân hàng của bạn qua mã VietQR; PanelForge không lưu số thẻ hay thông tin đăng nhập ngân hàng.',
      ],
    ),
    (
      heading: '4. Dữ liệu chỉ lưu trên thiết bị',
      body: [
        'Danh sách Đọc sau, Theo dõi, Yêu thích, lịch sử đọc gần đây, tiến độ đọc, cài đặt giao diện và các chương đã tải ngoại tuyến '
            'được lưu trên thiết bị của bạn và không gửi lên máy chủ. Gỡ ứng dụng sẽ xoá các dữ liệu này.',
        'Ứng dụng lưu cookie phiên đăng nhập và mã thiết bị tin cậy (nếu bạn bật) để duy trì đăng nhập an toàn.',
      ],
    ),
    (
      heading: '5. Quảng cáo và theo dõi',
      body: [
        'Ứng dụng không hiển thị quảng cáo, không dùng SDK quảng cáo và không theo dõi bạn qua ứng dụng hay trang web khác.',
      ],
    ),
    (
      heading: '6. Chia sẻ dữ liệu',
      body: [
        'Không bán dữ liệu cá nhân. Dữ liệu chỉ được chia sẻ khi cần để vận hành dịch vụ (lưu trữ, gửi email xác thực, đăng nhập Google) '
            'hoặc theo yêu cầu của cơ quan có thẩm quyền.',
        'Khi bạn xem bản thảo qua mã Review, email/danh tính của bạn được in mờ trên trang và nhận xét bạn gửi được chuyển cho Studio đã mời.',
      ],
    ),
    (
      heading: '7. Bảo mật',
      body: [
        'Quyền đọc từng trang được máy chủ kiểm tra mỗi lần tải: trang ngoài phần xem trước không được gửi tới máy khi bạn chưa mở khóa. '
            'Mọi thay đổi trạng thái quan trọng (thanh toán, mở khóa, phát hành) đều được ghi nhật ký kiểm toán.',
      ],
    ),
    (
      heading: '8. Quyền của bạn',
      body: [
        'Xem và sửa thông tin hồ sơ trong Cài đặt › Hồ sơ; đổi mật khẩu; xoá thiết bị tin cậy; xoá lịch sử đọc và bộ nhớ đệm trên máy.',
        'Xoá tài khoản trong Cài đặt: tài khoản bị vô hiệu hóa; giao dịch được giữ lại cho mục đích đối soát. '
            'Cần hỗ trợ thêm về dữ liệu, hãy liên hệ qua mục Hỗ trợ.',
      ],
    ),
  ],
);

const copyrightNotice = LegalDocument(
  id: 'copyright',
  title: 'Bản quyền',
  updated: _updated,
  sections: [
    (
      heading: 'Nền tảng',
      body: ['Ứng dụng, giao diện và thương hiệu PanelForge — Bản quyền thuộc về PanelForge Studio.'],
    ),
    (
      heading: 'Tác phẩm',
      body: [
        'Mỗi bộ truyện thuộc bản quyền của Studio sáng tác ghi trên trang truyện. Studio quản lý nội dung, Publisher quy định giá phát hành.',
        'Mọi hình thức sao chép, chụp màn hình để phát tán, đăng lại hoặc dịch lại khi chưa được phép đều là vi phạm bản quyền.',
      ],
    ),
    (
      heading: 'Bảo vệ nội dung',
      body: [
        'Trang ngoài phần xem trước chỉ được máy chủ cấp cho người đã mở khóa; bản thảo chưa phát hành luôn có hình mờ mang danh tính người xem.',
        'Phát hiện nội dung PanelForge bị đăng lại trái phép? Hãy báo qua mục Hỗ trợ kèm đường dẫn.',
      ],
    ),
  ],
);

const faqDocument = LegalDocument(
  id: 'faq',
  title: 'Câu hỏi thường gặp',
  updated: _updated,
  sections: [
    (
      heading: 'Làm sao để đọc chương trả phí?',
      body: [
        'Chạm vào chương có biểu tượng ổ khóa, chọn "Dùng Ví để đọc" để mở khóa cả chương bằng số dư Ví hoặc chuyển khoản VietQR. '
            'Chọn "Đọc thử trang xem trước" để đọc các trang miễn phí trước khi quyết định.',
      ],
    ),
    (
      heading: 'Đã chuyển khoản nhưng Ví chưa có tiền?',
      body: [
        'Tiền vào Ví khi giao dịch được xác nhận đã nhận. Ứng dụng tự kiểm tra mỗi vài giây khi màn hình mã QR đang mở; '
            'bạn cũng có thể xem trạng thái đơn trong Cửa hàng › Lịch sử giao dịch. Quá lâu chưa được cộng, hãy liên hệ hỗ trợ kèm mã đơn.',
      ],
    ),
    (
      heading: 'Mua bản Tiếng Việt có đọc được bản English không?',
      body: ['Không. Mỗi ấn bản ngôn ngữ được mua riêng: mua ngôn ngữ nào đọc ngôn ngữ đó.'],
    ),
    (
      heading: 'VIP khác gì mua lẻ từng chương?',
      body: [
        'VIP cho đọc mọi chương trả phí khi gói còn hạn. Mua lẻ thì chương đó thuộc về bạn vĩnh viễn, kể cả khi không có VIP.',
      ],
    ),
    (
      heading: 'Đọc ngoại tuyến thế nào?',
      body: [
        'Trong danh sách chương, chạm biểu tượng tải về ở chương miễn phí hoặc chương đã mở khóa vĩnh viễn. Chương đã tải đọc được khi không có mạng.',
      ],
    ),
    (
      heading: 'Mã Review (REV-...) là gì?',
      body: [
        'Mã do Studio gửi để mời bạn xem và góp ý bản thảo chưa phát hành. Nhập mã trong Cài đặt › Nhập mã Review. '
            'Bản thảo có hình mờ mang tên bạn và hết hạn theo lời mời.',
      ],
    ),
    (
      heading: 'Dữ liệu Đọc sau / Yêu thích có mất khi đổi máy không?',
      body: [
        'Có. Các danh sách này hiện chỉ lưu trên thiết bị. Ví, giao dịch và chương đã mua thì gắn với tài khoản nên vẫn còn.',
      ],
    ),
  ],
);

const legalDocuments = <String, LegalDocument>{
  'terms': termsOfService,
  'privacy': privacyNotice,
  'copyright': copyrightNotice,
  'faq': faqDocument,
};
