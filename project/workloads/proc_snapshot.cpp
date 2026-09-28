// 指定 PID 後讀取 Linux /proc 的程序狀態；只輸出觀察值，不變更程序。
#include <charconv>
#include <fstream>
#include <iostream>
#include <string>
#include <string_view>
#include <system_error>

// 從指定欄位取出冒號後的值，去掉開頭空白；欄位不符時回傳空字串。
std::string field_value(const std::string& line, std::string_view field) {
    if (line.compare(0, field.size(), field) != 0) {
        return {};
    }
    const auto first = line.find_first_not_of(" \t", field.size());
    return first == std::string::npos ? std::string{} : line.substr(first);
}

// 接收 --pid 與正整數 PID，讀取其 /proc 狀態並輸出欄位；成功回傳 0，輸入錯誤回傳 2，讀取錯誤回傳 3。
int main(int argc, char* argv[]) {
    if (argc != 3 || std::string_view(argv[1]) != "--pid") {
        std::cerr << "用法: proc_snapshot --pid <正整數 PID>\n";
        return 2;
    }

    const std::string_view input(argv[2]);
    int pid = 0;
    const auto [end, error] = std::from_chars(input.data(), input.data() + input.size(), pid);
    if (error != std::errc{} || end != input.data() + input.size() || pid <= 0) {
        std::cerr << "PID 必須是正整數\n";
        return 2;
    }

    const std::string path = "/proc/" + std::to_string(pid) + "/status";
    std::ifstream status(path);
    if (!status) {
        std::cerr << "無法開啟 " << path << "；程序可能已結束，或目前帳號無權讀取\n";
        return 3;
    }

    std::string name;
    std::string state;
    std::string vmrss;
    std::string line;
    while (std::getline(status, line)) {
        if (line.compare(0, 5, "Name:") == 0) {
            name = field_value(line, "Name:");
        } else if (line.compare(0, 6, "State:") == 0) {
            state = field_value(line, "State:");
        } else if (line.compare(0, 6, "VmRSS:") == 0) {
            vmrss = field_value(line, "VmRSS:");
        }
    }
    if (status.bad() || name.empty() || state.empty()) {
        std::cerr << "讀取 " << path << " 失敗或缺少必要欄位\n";
        return 3;
    }

    // VmRSS 可能不存在；保留此事實，避免把缺少欄位誤寫成 0 kB。
    std::cout << "pid=" << pid << '\n'
              << "name=" << name << '\n'
              << "state=" << state << '\n'
              << "vmrss=" << (vmrss.empty() ? "unavailable" : vmrss) << '\n';
    return 0;
}
