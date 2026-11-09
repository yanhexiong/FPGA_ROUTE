#!/usr/bin/env bash
# make check：检验你在 tb_counter.v 里自己加的复位检查是否有效。
#   第 1 项：正确的 counter.v 应当 PASS，说明检查本身没写错（不误报）；
#   其余各项：mutants/ 里每个变异体（故意写错的计数器）应当 FAIL，说明检查能发现错误（不漏报）。
# 变异体文件的第 2 行注释是它的编号和名称，第 3–5 行是错误写法、原 testbench 为什么发现不了、规格要求。
set -u
cd "$(dirname "$0")"
TB="$PWD/tb_counter.v"
WORK=$(mktemp -d)                # 在临时目录里跑，不覆盖你的 sim 和 wave.vcd
trap 'rm -rf "$WORK"' EXIT

# 用指定的计数器跑一次 testbench，输出 PASS / FAIL / ERROR
run() {
    if ! iverilog -g2012 -o "$WORK/sim" "$1" "$TB" 2>"$WORK/err"; then
        echo ERROR; return
    fi
    local out
    out=$(cd "$WORK" && timeout 20 vvp sim 2>&1)
    if   echo "$out" | grep -q '^PASS'; then echo PASS
    elif echo "$out" | grep -qE 'FAIL|错误'; then echo FAIL
    else echo ERROR; fi
}

# 先确认文件分工没弄错：counter.v 和 mutants/ 是 make check 的固定样本，只有 tb_counter.v 归你改
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git diff --quiet HEAD -- counter.v mutants/; then
        echo "✗ 你改动了下面这些文件："
        git diff --name-only --relative HEAD -- counter.v mutants/ | sed 's#^#      #'
        echo "  它们是 make check 用来对照的固定样本，必须保持原样：counter.v 是正确答案，"
        echo "  mutants/ 里的变异体是故意写错的电路，本来就该是错的，不需要你修。"
        echo "  这道题只改 tb_counter.v。先恢复它们，再运行 make check："
        echo "      git checkout -- counter.v mutants/"
        echo "（make 接下来会打印一行 Error 1：表示检验没通过，不是程序坏了）"
        exit 1
    fi
    if git diff --quiet HEAD -- tb_counter.v; then
        echo "提示：tb_counter.v 和仓库里的原版一模一样，你还没有在里面加复位检查。"
        echo "      下面变异体 M1、M2 没检出是正常的，加完检查再运行 make check。"
        echo
    fi
fi

MUTANTS=(mutants/*.v)
TOTAL=$(( ${#MUTANTS[@]} + 1 ))
passed=0
echo "检验 tb_counter.v 中自己加的复位检查：同一份 testbench 依次和下面 $TOTAL 个被测电路一起运行（不用改 counter.v）"

r=$(run "$PWD/counter.v")
if [ "$r" = PASS ]; then
    echo "[1/$TOTAL] 正确的计数器 counter.v：应为 PASS，实际 PASS  ✓"
    passed=$((passed + 1))
elif [ "$r" = FAIL ]; then
    echo "[1/$TOTAL] 正确的计数器 counter.v：应为 PASS，实际 FAIL  ✗"
    echo "      检查本身写错了，电路没错也报错。运行 make 看第一条 FAIL 出在哪一拍，"
    echo "      常见原因：参考答案 golden 没有跟着清零，或者清零早了、晚了一拍。"
else
    echo "[1/$TOTAL] 正确的计数器 counter.v：编译或运行出错  ✗"
    cat "$WORK/err" 2>/dev/null
    echo "      先运行 make，把 testbench 的语法错误改掉。"
    exit 1
fi

i=1
for m in "${MUTANTS[@]}"; do
    i=$((i + 1))
    name=$(sed -n '2{s#^// *##;s#：\(.*\)#（\1）#;p}' "$m")   # 例如「变异体 M1（复位优先级低于使能）」
    r=$(run "$PWD/$m")
    if [ "$r" = FAIL ]; then
        echo "[$i/$TOTAL] $name：应为 FAIL，实际 FAIL  ✓"
        passed=$((passed + 1))
    elif [ "$r" = PASS ]; then
        echo "[$i/$TOTAL] $name：应为 FAIL，实际 PASS  ✗"
        sed -n '3,5s#^// *#      #p' "$m"
        echo "      要改的是 tb_counter.v：让你加的检查在这个错误电路上报出 FAIL。不要改 $m"
    else
        echo "[$i/$TOTAL] $name：编译或运行出错  ✗"
        cat "$WORK/err" 2>/dev/null
    fi
done

echo
if [ "$passed" = "$TOTAL" ]; then
    echo "结果：$passed/$TOTAL 项通过。你加的复位检查既不误报，也能发现这些复位错误。"
else
    echo "结果：$passed/$TOTAL 项通过，还没完成。"
    echo "（make 接下来会打印一行 Error 1：表示检验没通过，不是程序坏了。3 项全部通过后这行就没有了）"
    exit 1
fi
