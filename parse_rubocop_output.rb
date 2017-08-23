#===============================================================
# parse_rubocop_output.rb
#                                    Created by Odawara-100ren
#===============================================================
# Usage:
# $ rubocop -f j -o out.json
# $ ruby parse_rubocop_output.rb out.json
# # CSV file "rubocop_file_stat.csv" will be created.

require "json"
require "csv"

# 2次元配列を転置する
# Array#transposeだと配列サイズの不一致によるエラーが発生するので自前で実装
# @param [Array<Array>] array
# @return 転置された配列
def transpose_f(array)
  transposed_array = []
  array.each.with_index do |row, row_no|
    row.each.with_index do |_, col_no|
      transposed_array[col_no] ||= []
      transposed_array[col_no][row_no] = array[row_no][col_no]
    end
  end
  transposed_array
end

# 違反箇所情報を文字列で返す
# @param [String] path ファイルパス
# @param [Hash] h 配列offensesの各ハッシュ要素
# @return [String] 発生位置情報
def file_info(path, h)
  info = "#{h["severity"][0,1].upcase}: " +
    "#{path}(#{h["location"]["line"]},#{h["location"]["column"]}) "
  m = h["message"].match(/\[[0-9]+(\.[0-9]+)?\/[0-9]+\]/)
  info += m[0] if m
  info
end

# 数値的なメトリクス情報のみ取得
def get_metrics(h)
  m = h["message"].match(/\[([0-9]+(\.[0-9]+)?)\/[0-9]+\]/)
  m ? m[1] : nil
end

# 変数の定義
OUTPUT_FILE="rubocop_file_stat.csv"
res = nil
offenses = {}

# 出力されたjson形式のファイルをCSV形式にフォーマットし直す
# @see http://rubocop.readthedocs.io/en/latest/formatters/#json-formatter
File.open(ARGV[0]) do |f|
  json_str = f.read
  res = JSON.parse(json_str)
end

res["files"].each do |t_f|
  path = t_f["path"]
  t_f["offenses"].each do |o|
    # offensesの各配列要素o（ハッシュ）が持つキー
    # - severity
    # - message
    # - cop_name
    # - corrected
    # - location(line, column, length)
    cop_name = o["cop_name"]
    unless offenses[cop_name]
      # 初期化
      offenses[cop_name] = {
        count: 1,
        files: [file_info(path, o)],
        metrics: [get_metrics(o)],
        severity: o["severity"],
        message: o["message"],
      }
    else
      offenses[cop_name][:count] += 1
      offenses[cop_name][:files] << file_info(path, o)
      offenses[cop_name][:metrics] << get_metrics(o)
    end
  end
end

rows = [["Cop Name", "Severity", "Message", "Count"]]
offenses.each do |cop_name, h|
  rows << [cop_name, h[:severity].upcase, h[:message], h[:count]]
end
cols1 = transpose_f(rows)

rows = [["Path & Location"]]
offenses.each do |_, h|
  rows << h[:files]
end
cols2 = transpose_f(rows)

rows = [["Metrics"]]
offenses.each do |_, h|
  rows << h[:metrics]
end
cols3 = transpose_f(rows)

CSV.open(OUTPUT_FILE, "wb") do |csv|
  cols1.each { |row| csv << row }
  cols2.each { |row| csv << row }
  cols3.each { |row| csv << row }
end

puts "'#{OUTPUT_FILE}' is created successfully!"
