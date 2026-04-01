# flutter_contact_demo

基于 Flutter 的通讯录功能示例，覆盖两类典型场景：

- 原生联系人选择器：使用 `flutter_native_contact_picker_plus`
- 完整通讯录读取与搜索：使用 `contactos`

## 已实现内容

- Android / iOS 通讯录权限配置
- 系统原生联系人选择
- 选择联系人中的特定手机号
- iOS 多联系人选择入口
- 读取完整通讯录列表
- 本地姓名 / 手机号 / 邮箱搜索
- 按需加载联系人头像
- 写入一个示例联系人到系统通讯录
- 权限拒绝与永久拒绝提示

## 运行方式

```bash
cd flutter_contact_demo
flutter pub get
flutter run
```

## 测试建议

- 尽量用 Android 或 iPhone 真机测试
- 优先覆盖首次授权、拒绝、永久拒绝三种权限路径
- “添加示例联系人”会真实写入系统通讯录，只建议在测试机演示

## 依赖

- `flutter_native_contact_picker_plus: ^1.3.1`
- `contactos: ^2.0.1`
- `permission_handler: ^12.0.1`
