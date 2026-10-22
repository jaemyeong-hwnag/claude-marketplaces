#!/usr/bin/env bash
# kotlin-spring-aitest-coverage 스크립트 회귀 테스트 — method-coverage-get.sh · diff-coverage-validate.sh ·
# aitest-coverage-validate.sh(훅) · Docker 준비 템플릿. 임시 git 저장소 + 손으로 만든 JaCoCo XML 로 돈다.
# ./gradlew 와 javap 는 스텁이다 — javap 스텁은 클래스 파일 자리에 둔 실제 javap 출력을 그대로 내므로 JDK 없이 결정적으로 돈다.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TEST_DIR/.." && pwd)"
M="$PLUGIN_ROOT/scripts/method-coverage-get.sh"
D="$PLUGIN_ROOT/scripts/diff-coverage-validate.sh"
H="$PLUGIN_ROOT/scripts/aitest-coverage-validate.sh"
E_TMPL="$PLUGIN_ROOT/skills/kotlin-aitest-environment-create/templates/scripts/ensure-docker-for-aitest.sh.tmpl"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/kt-aitest-tc.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP/tmpdir"; mkdir -p "$TMPDIR"

mkdir -p "$TMP/bin"
cat > "$TMP/bin/javap" <<'EOS'
#!/bin/sh
for a in "$@"; do f="$a"; done
cat "$f"
EOS
chmod +x "$TMP/bin/javap"
export AITEST_JAVAP="$TMP/bin/javap"

FILTER="${1:-}"
PASS=0; FAIL=0; SKIP=0; OUT=""; CODE=0; TC_ID=""; TC_DESC=""; TC_FAILED=0; TC_ON=1

flush_tc() {
  [ -n "$TC_ID" ] || return 0
  if [ "$TC_ON" = 0 ]; then SKIP=$((SKIP+1))
  elif [ "$TC_FAILED" = 0 ]; then PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m %-8s %s\n' "$TC_ID" "$TC_DESC"
  else FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-8s %s\n' "$TC_ID" "$TC_DESC"; printf '%s\n' "$OUT" | sed 's/^/            /'; fi
  TC_ID=""
}
tc() {
  flush_tc; TC_ID="$1"; TC_DESC="$2"; TC_FAILED=0
  if [ -z "$FILTER" ] || [[ "$1" == "$FILTER"* ]]; then TC_ON=1; else TC_ON=0; fi
}
on() { [ "$TC_ON" = 1 ]; }
fail_tc() { on || return 0; printf '            ↳ %s\n' "$1"; TC_FAILED=1; }
run() { on || return 0; OUT="$("$@" 2>&1)"; CODE=$?; }
run_in() { on || return 0; local input="$1"; shift; OUT="$(printf '%s' "$input" | "$@" 2>&1)"; CODE=$?; }
expect_code() { on || return 0; [ "$CODE" = "$1" ] || fail_tc "종료 코드 $CODE (기대 $1)"; }
expect_out() { on || return 0; printf '%s' "$OUT" | grep -qF -- "$1" || fail_tc "출력에 '$1' 없음"; }
expect_not() { on || return 0; printf '%s' "$OUT" | grep -qF -- "$1" && fail_tc "출력에 '$1' 가 있으면 안 됩니다"; return 0; }
expect_empty() { on || return 0; [ -z "$OUT" ] || fail_tc "출력이 없어야 합니다"; }

# --- 실제 javap 출력 (Kotlin 2.2.21 · JDK 17.0.17, javap -p -s -l) — 아래 소스를 컴파일한 그대로 ---------
javap_of() { # $1=클래스 (Pricing$Companion 처럼 $ 포함)
  case "$1" in
    'FooController') cat <<'JAVAP'
Compiled from "FooController.kt"
public class com.ex.app.FooController {
  public com.ex.app.FooController();
    descriptor: ()V
    LineNumberTable:
      line 5: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/FooController;

  public int bar(int);
    descriptor: (I)I
    LineNumberTable:
      line 8: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       4     0  this   Lcom/ex/app/FooController;
          0       4     1     x   I

  public int baz();
    descriptor: ()I
    LineNumberTable:
      line 12: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       2     0  this   Lcom/ex/app/FooController;
}
JAVAP
      ;;
    'Legacy') cat <<'JAVAP'
Compiled from "Legacy.kt"
public final class com.ex.app.Legacy {
  public com.ex.app.Legacy();
    descriptor: ()V
    LineNumberTable:
      line 3: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/Legacy;

  public final int old(int);
    descriptor: (I)I
    LineNumberTable:
      line 5: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       4     0  this   Lcom/ex/app/Legacy;
          0       4     1     x   I
}
JAVAP
      ;;
    'Pricing') cat <<'JAVAP'
Compiled from "Pricing.kt"
public final class com.ex.app.pricing.Pricing {
  public static final com.ex.app.pricing.Pricing$Companion Companion;
    descriptor: Lcom/ex/app/pricing/Pricing$Companion;

  private final java.lang.String name;
    descriptor: Ljava/lang/String;

  private int rate;
    descriptor: I

  private final java.lang.String tag;
    descriptor: Ljava/lang/String;

  public java.lang.String memo;
    descriptor: Ljava/lang/String;

  public com.ex.app.pricing.Pricing(java.lang.String, int);
    descriptor: (Ljava/lang/String;I)V
    LineNumberTable:
      line 3: 6
      line 7: 20
      line 8: 21
      line 8: 38
      line 9: 41
      line 3: 42
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      43     0  this   Lcom/ex/app/pricing/Pricing;
          0      43     1  name   Ljava/lang/String;
          0      43     2  rate   I

  public com.ex.app.pricing.Pricing(java.lang.String, int, int, kotlin.jvm.internal.DefaultConstructorMarker);
    descriptor: (Ljava/lang/String;IILkotlin/jvm/internal/DefaultConstructorMarker;)V
    LineNumberTable:
      line 3: 0

  public final java.lang.String getName();
    descriptor: ()Ljava/lang/String;
    LineNumberTable:
      line 3: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/pricing/Pricing;

  public final int getRate();
    descriptor: ()I
    LineNumberTable:
      line 3: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/pricing/Pricing;

  public final void setRate(int);
    descriptor: (I)V
    LineNumberTable:
      line 3: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       6     0  this   Lcom/ex/app/pricing/Pricing;
          0       6     1 <set-?>   I

  public final java.lang.String getMemo();
    descriptor: ()Ljava/lang/String;
    LineNumberTable:
      line 5: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      17     0  this   Lcom/ex/app/pricing/Pricing;

  public final void setMemo(java.lang.String);
    descriptor: (Ljava/lang/String;)V
    LineNumberTable:
      line 5: 6
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      12     0  this   Lcom/ex/app/pricing/Pricing;
          0      12     1 <set-?>   Ljava/lang/String;

  public final long apply(long, int);
    descriptor: (JI)J
    LineNumberTable:
      line 12: 0
      line 13: 12
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
         12      14     4 discounted   J
          0      26     0  this   Lcom/ex/app/pricing/Pricing;
          0      26     1 price   J
          0      26     3 percent   I

  public static long apply$default(com.ex.app.pricing.Pricing, long, int, int, java.lang.Object);
    descriptor: (Lcom/ex/app/pricing/Pricing;JIILjava/lang/Object;)J
    LineNumberTable:
      line 11: 0

  public final int twice(int);
    descriptor: (I)I
    LineNumberTable:
      line 16: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       4     0  this   Lcom/ex/app/pricing/Pricing;
          0       4     1     x   I

  public static int twice$default(com.ex.app.pricing.Pricing, int, int, java.lang.Object);
    descriptor: (Lcom/ex/app/pricing/Pricing;IILjava/lang/Object;)I
    LineNumberTable:
      line 16: 0

  public final java.lang.String label(java.lang.String);
    descriptor: (Ljava/lang/String;)Ljava/lang/String;
    LineNumberTable:
      line 21: 6
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      17     0  this   Lcom/ex/app/pricing/Pricing;
          0      17     1 prefix   Ljava/lang/String;

  public static java.lang.String label$default(com.ex.app.pricing.Pricing, java.lang.String, int, java.lang.Object);
    descriptor: (Lcom/ex/app/pricing/Pricing;Ljava/lang/String;ILjava/lang/Object;)Ljava/lang/String;
    LineNumberTable:
      line 18: 0
      line 19: 6
      line 18: 15

  public final java.lang.Runnable runner();
    descriptor: ()Ljava/lang/Runnable;
    LineNumberTable:
      line 24: 0
      line 26: 6
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       7     0  this   Lcom/ex/app/pricing/Pricing;

  public final int withLocal(int);
    descriptor: (I)I
    LineNumberTable:
      line 32: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       7     0  this   Lcom/ex/app/pricing/Pricing;
          0       7     1     x   I

  public final int useInline(java.util.List<java.lang.Integer>);
    descriptor: (Ljava/util/List;)I
    LineNumberTable:
      line 36: 6
      line 65: 10
      line 66: 13
      line 67: 46
      line 69: 61
      line 36: 63
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
         46      12     6  x$iv   I
         10      53     3 $i$f$sumOfPositive   I
         13      50     4  s$iv   I
          8      55     2 $this$sumOfPositive$iv   Ljava/util/List;
          0      64     0  this   Lcom/ex/app/pricing/Pricing;
          0      64     1    xs   Ljava/util/List;

  private static final void runner$lambda$0(com.ex.app.pricing.Pricing);
    descriptor: (Lcom/ex/app/pricing/Pricing;)V
    LineNumberTable:
      line 25: 0
      line 26: 11
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      12     0 this$0   Lcom/ex/app/pricing/Pricing;

  private static final int withLocal$helper(int);
    descriptor: (I)I
    LineNumberTable:
      line 30: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       4     0     y   I

  public static final com.ex.app.pricing.Pricing create(java.lang.String);
    descriptor: (Ljava/lang/String;)Lcom/ex/app/pricing/Pricing;
    LineNumberTable:
      line 43: 7
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       8     0  name   Ljava/lang/String;

  static {};
    descriptor: ()V
}
JAVAP
      ;;
    'Pricing$Companion') cat <<'JAVAP'
Compiled from "Pricing.kt"
public final class com.ex.app.pricing.Pricing$Companion {
  private com.ex.app.pricing.Pricing$Companion();
    descriptor: ()V
    LineNumberTable:
      line 39: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/pricing/Pricing$Companion;

  public final com.ex.app.pricing.Pricing create(java.lang.String);
    descriptor: (Ljava/lang/String;)Lcom/ex/app/pricing/Pricing;
    LineNumberTable:
      line 42: 6
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      18     0  this   Lcom/ex/app/pricing/Pricing$Companion;
          0      18     1  name   Ljava/lang/String;

  public final int plain();
    descriptor: ()I
    LineNumberTable:
      line 46: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       2     0  this   Lcom/ex/app/pricing/Pricing$Companion;

  public com.ex.app.pricing.Pricing$Companion(kotlin.jvm.internal.DefaultConstructorMarker);
    descriptor: (Lkotlin/jvm/internal/DefaultConstructorMarker;)V
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/pricing/Pricing$Companion;
          0       5     1 $constructor_marker   Lkotlin/jvm/internal/DefaultConstructorMarker;
}
JAVAP
      ;;
    'PricingKt') cat <<'JAVAP'
Compiled from "Pricing.kt"
public final class com.ex.app.pricing.PricingKt {
  public static final int sumOfPositive(java.util.List<java.lang.Integer>);
    descriptor: (Ljava/util/List;)I
    LineNumberTable:
      line 54: 8
      line 55: 10
      line 56: 40
      line 58: 53
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
         40      10     4     x   I
          8      47     1 $i$f$sumOfPositive   I
         10      45     2     s   I
          0      55     0 $this$sumOfPositive   Ljava/util/List;

  public static final int topLevel(int);
    descriptor: (I)I
    LineNumberTable:
      line 62: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       4     0     x   I
}
JAVAP
      ;;
    'Line') cat <<'JAVAP'
Compiled from "Pricing.kt"
public final class com.ex.app.pricing.Line {
  private final int qty;
    descriptor: I

  private final long price;
    descriptor: J

  public com.ex.app.pricing.Line(int, long);
    descriptor: (IJ)V
    LineNumberTable:
      line 51: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      15     0  this   Lcom/ex/app/pricing/Line;
          0      15     1   qty   I
          0      15     2 price   J

  public final int getQty();
    descriptor: ()I
    LineNumberTable:
      line 51: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/pricing/Line;

  public final long getPrice();
    descriptor: ()J
    LineNumberTable:
      line 51: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/pricing/Line;

  public final int component1();
    descriptor: ()I
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/pricing/Line;

  public final long component2();
    descriptor: ()J
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/app/pricing/Line;

  public final com.ex.app.pricing.Line copy(int, long);
    descriptor: (IJ)Lcom/ex/app/pricing/Line;
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      10     0  this   Lcom/ex/app/pricing/Line;
          0      10     1   qty   I
          0      10     2 price   J

  public static com.ex.app.pricing.Line copy$default(com.ex.app.pricing.Line, int, long, int, java.lang.Object);
    descriptor: (Lcom/ex/app/pricing/Line;IJILjava/lang/Object;)Lcom/ex/app/pricing/Line;

  public java.lang.String toString();
    descriptor: ()Ljava/lang/String;
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      14     0  this   Lcom/ex/app/pricing/Line;

  public int hashCode();
    descriptor: ()I
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          8      15     1 result   I
          0      23     0  this   Lcom/ex/app/pricing/Line;

  public boolean equals(java.lang.Object);
    descriptor: (Ljava/lang/Object;)Z
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0      50     0  this   Lcom/ex/app/pricing/Line;
          0      50     1 other   Ljava/lang/Object;
}
JAVAP
      ;;
    'PriceCalculator') cat <<'JAVAP'
Compiled from "PriceCalculator.kt"
public final class com.ex.core.PriceCalculator {
  public com.ex.core.PriceCalculator();
    descriptor: ()V
    LineNumberTable:
      line 3: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       5     0  this   Lcom/ex/core/PriceCalculator;

  public final int bar(int);
    descriptor: (I)I
    LineNumberTable:
      line 5: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       4     0  this   Lcom/ex/core/PriceCalculator;
          0       4     1     x   I

  public final int secret$core(int);
    descriptor: (I)I
    LineNumberTable:
      line 9: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       4     0  this   Lcom/ex/core/PriceCalculator;
          0       4     1     x   I
}
JAVAP
      ;;
    'PriceCalculatorKt') cat <<'JAVAP'
Compiled from "PriceCalculator.kt"
public final class com.ex.core.PriceCalculatorKt {
  public static final long addMoney-trLV_Ao(long, long);
    descriptor: (JJ)J
    LineNumberTable:
      line 17: 0
    LocalVariableTable:
      Start  Length  Slot  Name   Signature
          0       4     0 $v$c$com-ex-core-Money$-a$0   J
          0       4     2 $v$c$com-ex-core-Money$-b$0   J
}
JAVAP
      ;;
  esac
}

# --- 픽스처 소스 — 위 javap 출력을 만든 소스와 줄이 같다 -------------------------------
# FooController 꼴: <init> 5 · bar 8 · baz 12. 실행 줄 8 · 12. $4 = RestController(기본) · Service
controller_src() { # $1=패키지 $2=클래스 $3=bar 반환식 [$4=애노테이션]
  local ann="${4:-RestController}" imp="org.springframework.web.bind.annotation.RestController"
  [ "$ann" = "Service" ] && imp="org.springframework.stereotype.Service"
  cat <<EOF
package $1

import $imp

@$ann
class $2 {
    fun bar(x: Int): Int {
        return $3
    }

    fun baz(): Int {
        return 2
    }
}
EOF
}

pricing_src() {
  cat <<'EOF'
package com.ex.app.pricing

class Pricing(val name: String, var rate: Int = 10) {
    private val tag: String
    lateinit var memo: String

    init {
        tag = name.uppercase()
    }

    fun apply(price: Long, percent: Int = rate): Long {
        val discounted = price - price * percent / 100
        return if (discounted < 0) 0 else discounted
    }

    fun twice(x: Int = 1) = x * 2

    fun label(
        prefix: String = name.take(1),
    ): String {
        return prefix + tag
    }

    fun runner(): Runnable = Runnable {
        println(tag)
    }

    fun withLocal(x: Int): Int {
        fun helper(y: Int): Int {
            return y * 2
        }
        return helper(x) + 1
    }

    fun useInline(xs: List<Int>): Int {
        return xs.sumOfPositive()
    }

    companion object {
        @JvmStatic
        fun create(name: String): Pricing {
            return Pricing(name)
        }

        fun plain(): Int {
            return 1
        }
    }
}

data class Line(val qty: Int, val price: Long)

inline fun List<Int>.sumOfPositive(): Int {
    var s = 0
    for (x in this) {
        if (x > 0) s += x
    }
    return s
}

fun topLevel(x: Int): Int {
    return x * 3
}
EOF
}

legacy_src() {
  cat <<'EOF'
package com.ex.app

class Legacy {
    fun old(x: Int): Int {
        return x - 1
    }
}
EOF
}

core_calc_src() {
  cat <<'EOF'
package com.ex.core

class PriceCalculator {
    fun bar(x: Int): Int {
        return x + 1
    }

    internal fun secret(x: Int): Int {
        return x * 2
    }
}

@JvmInline
value class Money(val amount: Long)

fun addMoney(a: Money, b: Money): Long {
    return a.amount + b.amount
}
EOF
}

# 클래스 파일 자리에 javap 출력을 둔다 (javap 스텁이 그대로 낸다). $1=모듈 디렉터리("" = 루트) $2=패키지 $3=클래스 [$4=픽스처]
# 픽스처를 주지 않으면 FooController 출력에서 이름만 바꾼다 — controller_src 와 같은 꼴이다
put_class() {
  local dir="${1:+$1/}build/classes/kotlin/main/${2//.//}" fix="${4:-}"
  mkdir -p "$dir"
  if [ -n "$fix" ]; then javap_of "$fix" > "$dir/$3.class"
  else javap_of FooController | sed "s/com\.ex\.app\.FooController/$2.$3/g; s#com/ex/app/FooController#${2//.//}/$3#g" > "$dir/$3.class"; fi
}

# JaCoCo XML 한 줄 (controller_src 꼴). $1=출력 $2=패키지 경로 $3=클래스 $4=bar missed $5=baz missed [$6=소스 파일 이름]
jacoco_xml() {
  local out="$1" pkg="$2" cls="$3" bm="$4" zm="$5" src="${6:-$3.kt}"
  mkdir -p "$(dirname "$out")"
  printf '%s' "<?xml version=\"1.0\"?><report name=\"t\"><package name=\"$pkg\"><class name=\"$pkg/$cls\" sourcefilename=\"$src\"><method name=\"bar\" desc=\"(I)I\" line=\"8\"><counter type=\"INSTRUCTION\" missed=\"$bm\" covered=\"$((10 - bm))\"/></method><method name=\"baz\" desc=\"()I\" line=\"12\"><counter type=\"INSTRUCTION\" missed=\"$zm\" covered=\"$((10 - zm))\"/></method></class><sourcefile name=\"$src\"><line nr=\"8\" mi=\"$bm\" ci=\"$((10 - bm))\" mb=\"0\" cb=\"0\"/><line nr=\"12\" mi=\"$zm\" ci=\"$((10 - zm))\" mb=\"0\" cb=\"0\"/></sourcefile></package></report>" > "$out"
}

# Pricing.kt 의 메서드 — 실제 JaCoCo 0.8.15 리포트에 나온 그대로 (클래스|이름|desc|시작 줄|명령 수)
PRICING_METHODS='Pricing|<init>|(Ljava/lang/String;I)V|3|20
Pricing|<init>|(Ljava/lang/String;IILkotlin/jvm/internal/DefaultConstructorMarker;)V|3|10
Pricing|getName|()Ljava/lang/String;|3|3
Pricing|getRate|()I|3|3
Pricing|setRate|(I)V|3|4
Pricing|getMemo|()Ljava/lang/String;|5|4
Pricing|setMemo|(Ljava/lang/String;)V|5|4
Pricing|apply|(JI)J|12|18
Pricing|apply$default|(Lcom/ex/app/pricing/Pricing;JIILjava/lang/Object;)J|11|11
Pricing|twice|(I)I|16|4
Pricing|twice$default|(Lcom/ex/app/pricing/Pricing;IILjava/lang/Object;)I|16|9
Pricing|label|(Ljava/lang/String;)Ljava/lang/String;|21|5
Pricing|label$default|(Lcom/ex/app/pricing/Pricing;Ljava/lang/String;ILjava/lang/Object;)Ljava/lang/String;|18|12
Pricing|runner|()Ljava/lang/Runnable;|24|3
Pricing|withLocal|(I)I|32|5
Pricing|useInline|(Ljava/util/List;)I|36|5
Pricing|runner$lambda$0|(Lcom/ex/app/pricing/Pricing;)V|25|6
Pricing|withLocal$helper|(I)I|30|4
Pricing|create|(Ljava/lang/String;)Lcom/ex/app/pricing/Pricing;|43|1
Line|<init>|(IJ)V|51|9
Line|getQty|()I|51|3
Line|getPrice|()J|51|3
PricingKt|sumOfPositive|(Ljava/util/List;)I|54|4
PricingKt|topLevel|(I)I|62|4
Pricing$Companion|create|(Ljava/lang/String;)Lcom/ex/app/pricing/Pricing;|42|8
Pricing$Companion|plain|()I|46|2'
PRICING_LINES="3 5 7 8 9 11 12 13 16 18 19 21 24 25 26 30 32 36 42 43 46 51 54 55 56 58 62"

# Pricing.kt 리포트. 기본은 전부 덮임 — @JvmStatic 브리지(Pricing|create)만 실제처럼 1 미커버.
# 인자 '클래스|이름[|desc]=missed' 로 그 메서드의 미커버 명령 수를 바꾼다. DECOY=1 이면 디렉터리 이름 패키지(pricing)를 앞에 둔다
pricing_xml() {
  local out="$1"; shift
  mkdir -p "$(dirname "$out")"
  {
    printf '<?xml version="1.0"?><report name="t">'
    [ "${DECOY:-0}" = 1 ] && printf '<package name="pricing"><class name="pricing/Pricing" sourcefilename="Pricing.kt"><method name="apply" desc="(JI)J" line="12"><counter type="INSTRUCTION" missed="18" covered="0"/></method></class><sourcefile name="Pricing.kt"><line nr="12" mi="18" ci="0" mb="0" cb="0"/></sourcefile></package>'
    printf '<package name="com/ex/app/pricing">'
    printf '%s\n' "$PRICING_METHODS" | awk -F'|' -v ov="$*" '
    BEGIN { n = split(ov, o, " ") }
    {
      missed = ($1 == "Pricing" && $2 == "create") ? 1 : 0
      row = $1 "|" $2 "|" $3 "|"
      for (i = 1; i <= n; i++) { p = index(o[i], "="); k = substr(o[i], 1, p - 1) "|"; if (index(row, k) == 1) missed = substr(o[i], p + 1) + 0 }
      name = $2; gsub(/</, "\\&lt;", name); gsub(/>/, "\\&gt;", name)
      if ($1 != cls) { if (cls != "") printf "</class>"; cls = $1; printf "<class name=\"com/ex/app/pricing/%s\" sourcefilename=\"Pricing.kt\">", cls }
      printf "<method name=\"%s\" desc=\"%s\" line=\"%s\"><counter type=\"INSTRUCTION\" missed=\"%d\" covered=\"%d\"/></method>", name, $3, $4, missed, $5 - missed
    }
    END { printf "</class>" }'
    printf '<sourcefile name="Pricing.kt">'
    for l in $PRICING_LINES; do printf '<line nr="%s" mi="0" ci="1" mb="0" cb="0"/>' "$l"; done
    printf '</sourcefile></package></report>'
  } > "$out"
}

REPORT="build/reports/jacoco/aiTestReport/aiTestReport.xml"
MARKER_BLOCK='// >>> kotlin-spring-aitest-coverage
// <<< kotlin-spring-aitest-coverage'

# 새 저장소. $1=이름 → 경로 출력. 기본 구성: 멀티 모듈 app(환경 블록) + core, KTS.
repo() {
  local r="$TMP/$1"
  rm -rf "$r"; mkdir -p "$r"
  (
    cd "$r" || exit 1
    git init -q -b main . && git config user.email t@t && git config user.name t
    mkdir -p app/src/main/kotlin/com/ex/app app/src/aiTest/kotlin/com/ex/app core/src/main/kotlin/com/ex/core
    printf 'rootProject.name = "t"\ninclude("app", "core")\n' > settings.gradle.kts
    printf 'plugins {\n    kotlin("jvm")\n}\n\n%s\n' "$MARKER_BLOCK" > app/build.gradle.kts
    printf 'plugins {\n    kotlin("jvm")\n}\n' > core/build.gradle.kts
    controller_src com.ex.app FooController 'x + 1' > app/src/main/kotlin/com/ex/app/FooController.kt
    controller_src com.ex.core PriceCalculator 'x + 1' Service > core/src/main/kotlin/com/ex/core/PriceCalculator.kt
    printf 'build/\n' > .gitignore
    cat > gradlew <<'EOS'
#!/usr/bin/env bash
echo "$*" >> "${GRADLEW_CALLS:-/dev/null}"
exit "${GRADLEW_RC:-0}"
EOS
    chmod +x gradlew
    git add -A && git commit -qm init
    put_class app com.ex.app FooController
    put_class core com.ex.core PriceCalculator
  ) >/dev/null
  echo "$r"
}
# 모노레포 — 기본 구성을 backend/ 아래로 옮긴다 (git 루트 ≠ Gradle 루트). $1=이름 → 저장소 경로 출력
mono_repo() {
  local r; r="$(repo "$1")"
  ( cd "$r" && rm -rf app/build core/build && mkdir backend && git mv app core settings.gradle.kts gradlew .gitignore backend/ && git commit -qm mono
    cd backend && put_class app com.ex.app FooController && put_class core com.ex.core PriceCalculator ) >/dev/null
  echo "$r"
}
# Pricing.kt(디렉터리 pricing/, 패키지 com.ex.app.pricing)를 더한 저장소. $1=이름 → 경로 출력
pricing_repo() {
  local r; r="$(repo "$1")"
  ( cd "$r" && mkdir -p app/src/main/kotlin/pricing && pricing_src > app/src/main/kotlin/pricing/Pricing.kt && git add -A && git commit -qm pricing
    for c in Pricing 'Pricing$Companion' PricingKt Line; do put_class app com.ex.app.pricing "$c" "$c"; done ) >/dev/null
  echo "$r"
}
change_bar() { controller_src "$2" "$3" 'x + 2' ${4:+"$4"} > "$1"; }   # bar 의 8번째 줄만 바꾼다
touch_line() { # $1=파일 $2…=줄 번호 — 그 줄 끝에 주석을 붙여 바뀐 줄로 만든다
  local f="$1"; shift
  awk -v ls=" $* " 'index(ls, " " NR " ") { $0 = $0 " // changed" } 1' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}
aitest_for() { # $1=경로 $2=본문에 넣을 단어
  mkdir -p "$(dirname "$1")"
  printf 'package com.ex.app\n\n@AiTest\nclass %s {\n    // %s\n}\n' "$(basename "$1" .kt)" "$2" > "$1"
}
fresh_report() { sleep 1; jacoco_xml "$@"; }                 # mtime 이 소스보다 확실히 뒤가 되게
PR="app/src/main/kotlin/pricing/Pricing.kt"

hook_in() { printf '{"session_id":"%s","stop_hook_active":%s}' "$1" "${2:-false}"; }
state_of() { echo "$1/.claude/kotlin-spring-aitest-coverage"; }   # $1=Gradle 루트
# jq 만 뺀 PATH — PATH 의 각 디렉터리를 앞에서부터 링크해 같은 이름은 먼저 것이 이긴다
nojq_path() {
  local d nj="$TMP/nojq"
  if [ ! -d "$nj" ]; then
    mkdir -p "$nj"
    local IFS=:; for d in $PATH; do [ -d "$d" ] && ln -s "$d"/* "$nj"/ 2>/dev/null; done
    rm -f "$nj/jq"
  fi
  echo "$nj"
}

flush_tc; echo "== method-coverage-get.sh"

tc TC-M01 "변경 메서드가 100% 면 OK"
if on; then
  R="$(repo m01)"; change_bar "$R/app/src/main/kotlin/com/ex/app/FooController.kt" com.ex.app FooController
  jacoco_xml "$R/app/$REPORT" com/ex/app FooController 0 10
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/kotlin/com/ex/app/FooController.kt app
  expect_code 0; expect_out "OK app com.ex.app.FooController#bar(I)I line 8 → 100% (10/10)"; expect_not "baz"
fi

tc TC-M02 "변경 메서드가 100% 미만이면 FAIL"
if on; then
  R="$(repo m02)"; change_bar "$R/app/src/main/kotlin/com/ex/app/FooController.kt" com.ex.app FooController
  jacoco_xml "$R/app/$REPORT" com/ex/app FooController 3 0
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/kotlin/com/ex/app/FooController.kt app
  expect_code 1; expect_out "FAIL app com.ex.app.FooController#bar(I)I line 8 → 70% (7/10)"
fi

tc TC-M03 "바뀌지 않은 메서드는 0% 여도 판정하지 않는다"
if on; then
  R="$(repo m03)"; change_bar "$R/app/src/main/kotlin/com/ex/app/FooController.kt" com.ex.app FooController
  jacoco_xml "$R/app/$REPORT" com/ex/app FooController 0 10
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/kotlin/com/ex/app/FooController.kt
  expect_code 0; expect_not "FAIL"
fi

tc TC-M04 "untracked 새 파일은 전 줄을 변경으로 본다"
if on; then
  R="$(repo m04)"; controller_src com.ex.app BarService 'x' Service > "$R/app/src/main/kotlin/com/ex/app/BarService.kt"
  ( cd "$R" && put_class app com.ex.app BarService )
  jacoco_xml "$R/app/$REPORT" com/ex/app BarService 0 4
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/kotlin/com/ex/app/BarService.kt
  expect_code 1; expect_out "OK "; expect_out "#baz()I line 12 → 60%"
fi

tc TC-M05 "리포트가 없으면 FAIL"
if on; then
  R="$(repo m05)"; change_bar "$R/app/src/main/kotlin/com/ex/app/FooController.kt" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/kotlin/com/ex/app/FooController.kt
  expect_code 1; expect_out "missing JaCoCo XML report"
fi

tc TC-M06 "파일의 클래스가 리포트에 없으면 측정 대상 아님"
if on; then
  R="$(repo m06)"; change_bar "$R/app/src/main/kotlin/com/ex/app/FooController.kt" com.ex.app FooController
  jacoco_xml "$R/app/$REPORT" com/ex/other Other 0 0
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/kotlin/com/ex/app/FooController.kt
  expect_code 0; expect_out "class not in report"
fi

tc TC-M07 "같은 이름 파일이 다른 패키지에 있어도 섞지 않는다"
if on; then
  R="$(repo m07)"; change_bar "$R/app/src/main/kotlin/com/ex/app/FooController.kt" com.ex.app FooController
  jacoco_xml "$R/app/$REPORT" com/ex/other FooController 5 5
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/kotlin/com/ex/app/FooController.kt
  expect_code 0; expect_out "class not in report"
fi

flush_tc; echo "== method-coverage-get.sh — Kotlin 메서드 귀속 (실제 javap 줄 표)"

tc TC-K01 "패키지 ≠ 디렉터리 — package 선언으로 리포트를 찾는다"
if on; then
  R="$(pricing_repo k01)"; touch_line "$R/$PR" 12
  DECOY=1 pricing_xml "$R/app/$REPORT"
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 0; expect_out "OK app com.ex.app.pricing.Pricing#apply(JI)J line 12 → 100% (18/18)"
  touch_line "$R/$PR" 13; pricing_xml "$R/app/$REPORT" 'Pricing|apply|(JI)J=2'
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 1; expect_out "FAIL app com.ex.app.pricing.Pricing#apply(JI)J line 12 → 88% (16/18)"
fi

tc TC-K02 "@JvmStatic 브리지는 판정하지 않고 companion 메서드로 판정한다"
if on; then
  R="$(pricing_repo k02)"; touch_line "$R/$PR" 42 43
  pricing_xml "$R/app/$REPORT"
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 0; expect_out 'OK app com.ex.app.pricing.Pricing$Companion#create'; expect_not "Pricing#create("
fi

tc TC-K03 "같은 줄의 name\$default 는 빼고 name 으로 판정한다"
if on; then
  R="$(pricing_repo k03)"; touch_line "$R/$PR" 16
  pricing_xml "$R/app/$REPORT" 'Pricing|twice$default=9'
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 0; expect_out "OK app com.ex.app.pricing.Pricing#twice(I)I line 16 → 100%"; expect_not 'twice$default'
fi

tc TC-K04 "기본값 식 줄만 바꾸면 name\$default 를 판정한다"
if on; then
  R="$(pricing_repo k04)"; touch_line "$R/$PR" 19
  pricing_xml "$R/app/$REPORT" 'Pricing|label$default=12'
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 1; expect_out 'FAIL app com.ex.app.pricing.Pricing#label$default'; expect_not "#label(Ljava"
fi

tc TC-K05 "주 생성자 줄 — 접근자 · DefaultConstructorMarker 생성자는 빼고 <init> 으로 판정한다"
if on; then
  R="$(pricing_repo k05)"; touch_line "$R/$PR" 3
  pricing_xml "$R/app/$REPORT" 'Pricing|getName=3' 'Pricing|getRate=3' 'Pricing|setRate=4' 'Pricing|<init>|(Ljava/lang/String;IILkotlin/jvm/internal/DefaultConstructorMarker;)V=10'
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 0; expect_out "OK app com.ex.app.pricing.Pricing#<init>(Ljava/lang/String;I)V line 3 → 100%"
  expect_not "getName"; expect_not "DefaultConstructorMarker"
fi

tc TC-K06 "init 블록 줄은 주 생성자 <init> 으로 판정한다"
if on; then
  R="$(pricing_repo k06)"; touch_line "$R/$PR" 8
  pricing_xml "$R/app/$REPORT" 'Pricing|<init>|(Ljava/lang/String;I)V=5'
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 1; expect_out "FAIL app com.ex.app.pricing.Pricing#<init>(Ljava/lang/String;I)V line 3 → 75% (15/20)"
fi

tc TC-K07 "접근자만 있는 줄(lateinit)은 빼지 않고 접근자로 판정한다"
if on; then
  R="$(pricing_repo k07)"; touch_line "$R/$PR" 5
  pricing_xml "$R/app/$REPORT" 'Pricing|getMemo=4' 'Pricing|setMemo=4'
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 1; expect_out "FAIL app com.ex.app.pricing.Pricing#getMemo"; expect_out "FAIL app com.ex.app.pricing.Pricing#setMemo"
fi

tc TC-K08 "data class 헤더 줄 — 접근자는 빼고 <init> 으로 판정한다"
if on; then
  R="$(pricing_repo k08)"; touch_line "$R/$PR" 51
  pricing_xml "$R/app/$REPORT" 'Line|getPrice=3'
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 0; expect_out "OK app com.ex.app.pricing.Line#<init>(IJ)V line 51 → 100%"; expect_not "getPrice"
fi

tc TC-K09 "람다 본문 줄은 <바깥>\$lambda\$N 으로 판정한다"
if on; then
  R="$(pricing_repo k09)"; touch_line "$R/$PR" 25
  pricing_xml "$R/app/$REPORT" 'Pricing|runner$lambda$0=6'
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 1; expect_out 'FAIL app com.ex.app.pricing.Pricing#runner$lambda$0'; expect_not "#runner()"
fi

tc TC-K10 "로컬 함수 줄은 <바깥>\$<로컬> 로 판정한다 — 바깥 함수보다 앞줄이어도"
if on; then
  R="$(pricing_repo k10)"; touch_line "$R/$PR" 30
  pricing_xml "$R/app/$REPORT" 'Pricing|withLocal$helper=4'
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 1; expect_out 'FAIL app com.ex.app.pricing.Pricing#withLocal$helper(I)I'; expect_not "#withLocal(I)I"
fi

tc TC-K11 "최상위 함수는 <파일>Kt 클래스로 판정한다"
if on; then
  R="$(pricing_repo k11)"; touch_line "$R/$PR" 62
  pricing_xml "$R/app/$REPORT" 'PricingKt|topLevel=2'
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 1; expect_out "FAIL app com.ex.app.pricing.PricingKt#topLevel(I)I line 62 → 50% (2/4)"
fi

tc TC-K12 "inline 함수 본문은 inline 함수로 판정하고 인라인된 호출부(가짜 줄)는 고르지 않는다"
if on; then
  R="$(pricing_repo k12)"; touch_line "$R/$PR" 55
  pricing_xml "$R/app/$REPORT" 'Pricing|useInline=5'
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 0; expect_out "OK app com.ex.app.pricing.PricingKt#sumOfPositive(Ljava/util/List;)I"; expect_not "useInline"
fi

tc TC-K13 "companion 메서드는 <클래스>\$Companion 으로 판정한다"
if on; then
  R="$(pricing_repo k13)"; touch_line "$R/$PR" 46
  pricing_xml "$R/app/$REPORT" 'Pricing$Companion|plain=2'
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 1; expect_out 'FAIL app com.ex.app.pricing.Pricing$Companion#plain()I line 46 → 0% (0/2)'
fi

tc TC-K14 "src/main/java 의 .kt 도 build/classes/kotlin/main 으로 판정한다"
if on; then
  R="$(repo k14)"; mkdir -p "$R/app/src/main/java/com/ex/app"; legacy_src > "$R/app/src/main/java/com/ex/app/Legacy.kt"
  ( cd "$R" && git add -A && git commit -qm legacy && put_class app com.ex.app Legacy Legacy ) >/dev/null
  touch_line "$R/app/src/main/java/com/ex/app/Legacy.kt" 5; mkdir -p "$R/app/$(dirname "$REPORT")"
  printf '%s' '<?xml version="1.0"?><report name="t"><package name="com/ex/app"><class name="com/ex/app/Legacy" sourcefilename="Legacy.kt"><method name="old" desc="(I)I" line="5"><counter type="INSTRUCTION" missed="1" covered="3"/></method></class><sourcefile name="Legacy.kt"><line nr="5" mi="1" ci="3" mb="0" cb="0"/></sourcefile></package></report>' > "$R/app/$REPORT"
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" app/src/main/java/com/ex/app/Legacy.kt app
  expect_code 1; expect_out "FAIL app com.ex.app.Legacy#old(I)I line 5 → 75% (3/4)"
fi

tc TC-K15 "internal 의 \$<모듈> · value class 의 -<hash> 는 표시할 때 뗀다"
if on; then
  R="$(repo k15)"; core_calc_src > "$R/core/src/main/kotlin/com/ex/core/PriceCalculator.kt"
  ( cd "$R" && git add -A && git commit -qm calc && put_class core com.ex.core PriceCalculator PriceCalculator && put_class core com.ex.core PriceCalculatorKt PriceCalculatorKt ) >/dev/null
  touch_line "$R/core/src/main/kotlin/com/ex/core/PriceCalculator.kt" 9 17; mkdir -p "$R/app/$(dirname "$REPORT")"
  printf '%s' '<?xml version="1.0"?><report name="t"><package name="com/ex/core"><class name="com/ex/core/PriceCalculatorKt" sourcefilename="PriceCalculator.kt"><method name="addMoney-trLV_Ao" desc="(JJ)J" line="17"><counter type="INSTRUCTION" missed="0" covered="4"/></method></class><class name="com/ex/core/Money" sourcefilename="PriceCalculator.kt"/><class name="com/ex/core/PriceCalculator" sourcefilename="PriceCalculator.kt"><method name="secret$core" desc="(I)I" line="9"><counter type="INSTRUCTION" missed="0" covered="4"/></method></class><sourcefile name="PriceCalculator.kt"><line nr="9" mi="0" ci="4" mb="0" cb="0"/><line nr="17" mi="0" ci="4" mb="0" cb="0"/></sourcefile></package></report>' > "$R/app/$REPORT"
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" core/src/main/kotlin/com/ex/core/PriceCalculator.kt app
  expect_code 0; expect_out "OK app com.ex.core.PriceCalculator#secret(I)I line 9"; expect_out "OK app com.ex.core.PriceCalculatorKt#addMoney(JJ)J line 17"
fi

tc TC-K16 "javap 이 없으면 판정 불가(2)로 끝난다 (C-09)"
if on; then
  R="$(pricing_repo k16)"; touch_line "$R/$PR" 12
  pricing_xml "$R/app/$REPORT"
  AITEST_JAVAP="$TMP/no-javap" CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 2; expect_out "javap 이 없어"
fi

tc TC-K17 "클래스 파일이 없으면 판정 불가(2)로 끝난다 (C-09)"
if on; then
  R="$(pricing_repo k17)"; touch_line "$R/$PR" 12
  pricing_xml "$R/app/$REPORT"; rm -f "$R/app/build/classes/kotlin/main/com/ex/app/pricing/PricingKt.class"
  CLAUDE_PROJECT_DIR="$R" run "$M" HEAD "app/$REPORT" "$PR" app
  expect_code 2; expect_out "클래스 파일 없음"
fi

tc TC-K18 "macOS 기본 bash 3.2 로 새 파일 전 줄을 규칙대로 고른다"
if on; then
  if [ -x /bin/bash ] && /bin/bash -c '[ "${BASH_VERSINFO[0]}" -lt 4 ]'; then
    R="$(pricing_repo k18)"; git -C "$R" rm -q --cached "$PR"; git -C "$R" commit -qm untrack
    pricing_xml "$R/app/$REPORT"
    CLAUDE_PROJECT_DIR="$R" run /bin/bash "$M" HEAD "app/$REPORT" "$PR" app
    expect_code 0
    for s in 'Pricing#<init>(Ljava/lang/String;I)V' 'Pricing#apply$default' 'Pricing#twice(I)I' 'Pricing#label$default' 'Pricing#getMemo' \
             'Pricing#runner$lambda$0' 'Pricing$Companion#create' 'Line#<init>(IJ)V' 'PricingKt#sumOfPositive' 'PricingKt#topLevel'; do expect_out "$s"; done
    for s in 'Pricing#create(' 'twice$default' 'getName' 'DefaultConstructorMarker' 'getQty'; do expect_not "$s"; done
  else
    OUT="bash 3.2 없음 — 건너뜀"
  fi
fi

flush_tc; echo "== diff-coverage-validate.sh"

FOO="app/src/main/kotlin/com/ex/app/FooController.kt"
CALC="core/src/main/kotlin/com/ex/core/PriceCalculator.kt"
FOO_AITEST="app/src/aiTest/kotlin/com/ex/app/FooControllerAiTest.kt"

tc TC-D01 "diff 가 없으면 OK"
if on; then R="$(repo d01)"; CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "no diff"; fi

tc TC-D02 "main Kotlin · mapper · aiTest 밖의 변경만 있으면 OK — main 의 .java 는 보지 않는다"
if on; then
  R="$(repo d02)"; echo x > "$R/README.md"; mkdir -p "$R/app/src/main/java/com/ex/app"
  printf 'package com.ex.app;\n\n@RestController\npublic class JavaController {}\n' > "$R/app/src/main/java/com/ex/app/JavaController.java"
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "no main Kotlin/mapper/aiTest diff"
fi

tc TC-D03 "변경 Controller 에 aiTest 가 없으면 막는다 (C-01)"
if on; then
  R="$(repo d03)"; change_bar "$R/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 1; expect_out "app: com.ex.app.FooController ($FOO) 을 다루는 aiTest 가 없음"
fi

tc TC-D04 "aiTest 에 <Controller>…AiTest 클래스가 있으면 인정한다 (C-01)"
if on; then
  R="$(repo d04)"; change_bar "$R/$FOO" com.ex.app FooController
  aitest_for "$R/$FOO_AITEST" "MockMvc"
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 0; expect_out "check-only OK"
fi

tc TC-D05 "aiTest 본문에 클래스명이 단어로 나오면 인정한다 (C-01)"
if on; then
  R="$(repo d05)"; change_bar "$R/$FOO" com.ex.app FooController
  aitest_for "$R/app/src/aiTest/kotlin/com/ex/app/ApiAiTest.kt" "검증 대상: FooController.bar"
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 0
fi

tc TC-D06 "부분 문자열(FooControllerHelper)은 인정하지 않는다 (C-01)"
if on; then
  R="$(repo d06)"; change_bar "$R/$FOO" com.ex.app FooController
  aitest_for "$R/app/src/aiTest/kotlin/com/ex/app/ApiAiTest.kt" "FooControllerHelper"
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 1
fi

tc TC-D07 "report-only: 리포트가 없으면 막는다 (C-03)"
if on; then
  R="$(repo d07)"; change_bar "$R/$FOO" com.ex.app FooController
  aitest_for "$R/$FOO_AITEST" x
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 1; expect_out "app: JaCoCo 리포트 없음"
fi

tc TC-D08 "report-only: 리포트가 diff 보다 오래되면 막는다 (C-03)"
if on; then
  R="$(repo d08)"; aitest_for "$R/$FOO_AITEST" x
  jacoco_xml "$R/app/$REPORT" com/ex/app FooController 0 0
  sleep 1; change_bar "$R/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 1; expect_out "FooController.kt 가 리포트보다 최신"
fi

tc TC-D09 "report-only: 최신 리포트 + 100% 면 통과한다"
if on; then
  R="$(repo d09)"; change_bar "$R/$FOO" com.ex.app FooController
  aitest_for "$R/$FOO_AITEST" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 0 10
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "PASS (1 file(s), 1 module(s)"
fi

tc TC-D10 "report-only: 변경 메서드가 100% 미만이면 막는다 (C-02)"
if on; then
  R="$(repo d10)"; change_bar "$R/$FOO" com.ex.app FooController
  aitest_for "$R/$FOO_AITEST" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 2 0
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 1; expect_out "changed method JaCoCo below 100%"; expect_out "80%"
fi

tc TC-D11 "환경 블록이 없는 모듈의 main 변경은 판정 대상이 아니다"
if on; then
  R="$(repo d11)"; change_bar "$R/$CALC" com.ex.core PriceCalculator Service
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "no verifiable module diff"
fi

tc TC-D12 "libraryModules: 라이브러리 변경을 소비 모듈 리포트로 판정한다"
if on; then
  R="$(repo d12)"; mkdir -p "$R/.claude"; echo '{"libraryModules":{"core":["app"]}}' > "$R/.claude/kotlin-spring-aitest-coverage.json"
  change_bar "$R/$CALC" com.ex.core PriceCalculator Service
  fresh_report "$R/app/$REPORT" com/ex/core PriceCalculator 1 0
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 1; expect_out "FAIL app com.ex.core.PriceCalculator#bar(I)I line 8 → 90%"
fi

tc TC-D13 "libraryModules: 라이브러리 소스가 소비 모듈 리포트보다 새로우면 막는다"
if on; then
  R="$(repo d13)"; mkdir -p "$R/.claude"; echo '{"libraryModules":{"core":["app"]}}' > "$R/.claude/kotlin-spring-aitest-coverage.json"
  jacoco_xml "$R/app/$REPORT" com/ex/core PriceCalculator 0 0
  sleep 1; change_bar "$R/$CALC" com.ex.core PriceCalculator Service
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 1; expect_out "PriceCalculator.kt 가 리포트보다 최신"
fi

tc TC-D14 "단일 모듈 — 루트 build.gradle.kts 에 환경 블록이 있으면 루트를 모듈로 본다"
if on; then
  R="$TMP/d14"; rm -rf "$R"; mkdir -p "$R/src/main/kotlin/com/ex" "$R/src/aiTest/kotlin/com/ex"
  ( cd "$R" && git init -q -b main . && git config user.email t@t && git config user.name t
    printf 'rootProject.name = "single"\n' > settings.gradle.kts; printf 'plugins {\n    kotlin("jvm")\n}\n\n%s\n' "$MARKER_BLOCK" > build.gradle.kts
    printf 'build/\n' > .gitignore
    controller_src com.ex FooController 'x + 1' > src/main/kotlin/com/ex/FooController.kt
    git add -A && git commit -qm init && put_class "" com.ex FooController ) >/dev/null
  change_bar "$R/src/main/kotlin/com/ex/FooController.kt" com.ex FooController
  aitest_for "$R/src/aiTest/kotlin/com/ex/FooControllerAiTest.kt" x
  fresh_report "$R/$REPORT" com/ex FooController 0 0
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "OK . com.ex.FooController#bar"
fi

tc TC-D15 "중첩 모듈(apps:api) — apps/api/build.gradle.kts 의 환경 블록으로 찾는다"
if on; then
  R="$(repo d15)"; mkdir -p "$R/apps/api/src/main/kotlin/com/ex/api"
  printf '%s\n' "$MARKER_BLOCK" > "$R/apps/api/build.gradle.kts"
  controller_src com.ex.api FooController 'x + 1' > "$R/apps/api/src/main/kotlin/com/ex/api/FooController.kt"
  ( cd "$R" && git add -A && git commit -qm nested ) >/dev/null
  change_bar "$R/apps/api/src/main/kotlin/com/ex/api/FooController.kt" com.ex.api FooController
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 1; expect_out "apps:api: com.ex.api.FooController"
fi

tc TC-D16 "설정 .modules 가 환경 블록보다 우선한다"
if on; then
  R="$(repo d16)"; mkdir -p "$R/.claude"; echo '{"modules":["core"]}' > "$R/.claude/kotlin-spring-aitest-coverage.json"
  change_bar "$R/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 0; expect_out "no verifiable module diff"
fi

tc TC-D17 "aiTest 만 바뀌면 report-only 는 리포트 최신만 본다"
if on; then
  R="$(repo d17)"; aitest_for "$R/$FOO_AITEST" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 0 0
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_out "report-only PASS (aiTest-only diff"
fi

tc TC-D18 "실행: main 이 바뀐 모듈은 compileAiTestKotlin · aiTest 전체를 돌린다"
if on; then
  R="$(repo d18)"; change_bar "$R/$FOO" com.ex.app FooController
  aitest_for "$R/$FOO_AITEST" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 0 0
  export GRADLEW_CALLS="$TMP/d18.calls"; : > "$GRADLEW_CALLS"
  CLAUDE_PROJECT_DIR="$R" run "$D" HEAD; expect_code 0
  grep -q ':app:compileAiTestKotlin :app:aiTest$' "$GRADLEW_CALLS" || fail_tc "gradlew 호출: $(cat "$GRADLEW_CALLS")"
  grep -q -- '--tests' "$GRADLEW_CALLS" && fail_tc "main 변경인데 --tests 로 좁혔다"
  unset GRADLEW_CALLS
fi

tc TC-D19 "실행: aiTest 만 바뀌면 package 선언 + 최상위 클래스로 --tests 를 좁힌다"
if on; then
  R="$(repo d19)"; aitest_for "$R/$FOO_AITEST" x
  export GRADLEW_CALLS="$TMP/d19.calls"; : > "$GRADLEW_CALLS"
  CLAUDE_PROJECT_DIR="$R" run "$D" HEAD; expect_code 0
  grep -q -- ':app:aiTest --tests com.ex.app.FooControllerAiTest' "$GRADLEW_CALLS" || fail_tc "gradlew 호출: $(cat "$GRADLEW_CALLS")"
  unset GRADLEW_CALLS
fi

tc TC-D20 "실행: gradlew 가 실패하면 실패로 끝난다"
if on; then
  R="$(repo d20)"; aitest_for "$R/$FOO_AITEST" x
  GRADLEW_RC=1 CLAUDE_PROJECT_DIR="$R" run "$D" HEAD; [ "$CODE" != 0 ] || fail_tc "종료 코드 0"
fi

tc TC-D21 "설정 파일이 JSON 이 아니면 실행 오류(2)"
if on; then
  R="$(repo d21)"; mkdir -p "$R/.claude"; echo '{' > "$R/.claude/kotlin-spring-aitest-coverage.json"
  change_bar "$R/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 2; expect_out "파싱 실패"
fi

tc TC-D22 "macOS 기본 bash 3.2 로도 돈다"
if on; then
  if [ -x /bin/bash ] && /bin/bash -c '[ "${BASH_VERSINFO[0]}" -lt 4 ]'; then
    R="$(repo d22)"; mkdir -p "$R/.claude"; echo '{"libraryModules":{"core":["app"]}}' > "$R/.claude/kotlin-spring-aitest-coverage.json"
    change_bar "$R/$FOO" com.ex.app FooController
    change_bar "$R/$CALC" com.ex.core PriceCalculator Service
    aitest_for "$R/$FOO_AITEST" x
    fresh_report "$R/app/$REPORT" com/ex/app FooController 0 0
    CLAUDE_PROJECT_DIR="$R" run /bin/bash "$D" --report-only HEAD; expect_code 0; expect_out "class not in report"
  else
    OUT="bash 3.2 없음 — 건너뜀"
  fi
fi

tc TC-D23 "git 루트 ≠ Gradle 루트 — 변경 메서드가 100% 미만이면 막는다 (C-02)"
if on; then
  R="$(mono_repo d23)"; B="$R/backend"
  change_bar "$B/$FOO" com.ex.app FooController
  aitest_for "$B/$FOO_AITEST" x
  fresh_report "$B/app/$REPORT" com/ex/app FooController 10 0
  CLAUDE_PROJECT_DIR="$B" run "$D" --report-only HEAD; expect_code 1; expect_out "FAIL app com.ex.app.FooController#bar(I)I"
fi

tc TC-D24 "git 루트 ≠ Gradle 루트 — 최신 리포트 + 100% 면 통과한다"
if on; then
  R="$(mono_repo d24)"; B="$R/backend"
  change_bar "$B/$FOO" com.ex.app FooController
  aitest_for "$B/$FOO_AITEST" x
  fresh_report "$B/app/$REPORT" com/ex/app FooController 0 0
  CLAUDE_PROJECT_DIR="$B" run "$D" --report-only HEAD; expect_code 0; expect_out "changed method coverage 100%"
fi

tc TC-D25 "지운 Controller 는 C-01 대상이 아니다"
if on; then
  R="$(repo d25)"; aitest_for "$R/$FOO_AITEST" x
  ( cd "$R" && git add -A && git commit -qm t && git rm -q "$FOO" "$FOO_AITEST" ) >/dev/null
  CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 0; expect_not "FAIL"
fi

tc TC-D26 "Controller 를 지우며 다른 Controller 를 바꾸면 그 Controller 는 막는다 (C-01)"
if on; then
  R="$(repo d26)"; controller_src com.ex.app BarController 'x' > "$R/app/src/main/kotlin/com/ex/app/BarController.kt"
  ( cd "$R" && git add -A && git commit -qm bar && git rm -q "$FOO" ) >/dev/null
  change_bar "$R/app/src/main/kotlin/com/ex/app/BarController.kt" com.ex.app BarController
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 1; expect_out "BarController"; expect_not "FooController"
fi

tc TC-D27 "모듈 디렉터리에서 연 세션도 Gradle 루트 기준으로 보고 100% 미만을 막는다 (C-02)"
if on; then
  R="$(repo d27)"; change_bar "$R/$FOO" com.ex.app FooController
  aitest_for "$R/$FOO_AITEST" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 10 0
  CLAUDE_PROJECT_DIR="$R/app" run "$D" --report-only HEAD; expect_code 1; expect_out "FAIL app com.ex.app.FooController#bar(I)I"
fi

tc TC-D28 "--also: 그 ref 와 같은 파일은 보지 않는다"
if on; then
  R="$(repo d28)"; git -C "$R" branch other
  change_bar "$R/$FOO" com.ex.app FooController
  git -C "$R" commit -qam remote; git -C "$R" branch -f other HEAD; git -C "$R" reset -q --hard HEAD~1; git -C "$R" merge -q --no-ff --no-edit other
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only --also other HEAD~1; expect_code 0; expect_out "no diff vs HEAD~1"
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD~1; expect_code 1; expect_out "FooController"
fi

tc TC-D29 "파일 이름과 다른 @RestController 클래스도 C-01 대상이다"
if on; then
  R="$(repo d29)"; mkdir -p "$R/app/src/main/kotlin/web"
  controller_src com.ex.app.web OrderController 'x' > "$R/app/src/main/kotlin/web/OrderApi.kt"
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 1; expect_out "app: com.ex.app.web.OrderController (app/src/main/kotlin/web/OrderApi.kt)"
  aitest_for "$R/app/src/aiTest/kotlin/web/OrderControllerAiTest.kt" x
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 0
fi

tc TC-D30 "src/main/java 의 .kt 도 모듈 변경으로 본다 (C-01)"
if on; then
  R="$(repo d30)"; mkdir -p "$R/app/src/main/java/com/ex/app"
  controller_src com.ex.app JavaDirController 'x' > "$R/app/src/main/java/com/ex/app/JavaDirController.kt"
  CLAUDE_PROJECT_DIR="$R" run "$D" --check-only HEAD; expect_code 1; expect_out "com.ex.app.JavaDirController"
fi

tc TC-D31 "판정 도구(javap)가 없으면 실행 오류(2)로 끝난다 (C-09)"
if on; then
  R="$(repo d31)"; change_bar "$R/$FOO" com.ex.app FooController
  aitest_for "$R/$FOO_AITEST" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 0 0
  AITEST_JAVAP="$TMP/no-javap" CLAUDE_PROJECT_DIR="$R" run "$D" --report-only HEAD; expect_code 2; expect_out "변경 메서드를 판정할 수 없습니다 (C-09)"
fi

flush_tc; echo "== aitest-coverage-validate.sh (훅)"

tc TC-H01 "git 저장소가 아니면 조용히 통과한다"
if on; then mkdir -p "$TMP/nogit"; CLAUDE_PROJECT_DIR="$TMP/nogit" run_in "$(hook_in h01)" "$H"; expect_code 0; expect_empty; fi

tc TC-H02 "이번 요청에서 diff 가 그대로면 막지 않는다 (C-05)"
if on; then
  R="$(repo h02)"; change_bar "$R/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h02)" "$H" snapshot
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h02)" "$H"; expect_code 0; expect_empty
fi

tc TC-H03 "요청 중 Controller 를 바꾸고 aiTest 가 없으면 막는다 (C-01)"
if on; then
  R="$(repo h03)"; CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h03)" "$H" snapshot
  change_bar "$R/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h03)" "$H"; expect_code 2; expect_out "완료 보류(kotlin-spring-aitest-coverage)"; expect_out "aitest: skip"
fi

tc TC-H04 "최신 리포트 + 100% 면 통과한다"
if on; then
  R="$(repo h04)"; change_bar "$R/$FOO" com.ex.app FooController
  aitest_for "$R/$FOO_AITEST" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 0 0
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h04)" "$H"; expect_code 0; expect_empty
fi

tc TC-H05 "stop_hook_active 면 허용하고 systemMessage 로 남긴다 (C-08)"
if on; then
  R="$(repo h05)"; change_bar "$R/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h05 true)" "$H"; expect_code 0; expect_out '"systemMessage"'; expect_out "트랩 방지"
fi

tc TC-H06 "ACK 면제가 있으면 통과한다 (C-07)"
if on; then
  R="$(repo h06)"; change_bar "$R/$FOO" com.ex.app FooController
  mkdir -p "$(state_of "$R")"; echo 'aitest: skip 주석만 수정' > "$(state_of "$R")/h06.ack"
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h06)" "$H"; expect_code 0; expect_empty
fi

tc TC-H07 "환경 블록이 없으면 막지 않고 세션당 한 번만 알린다 (C-06)"
if on; then
  R="$(repo h07)"; printf 'plugins {\n    kotlin("jvm")\n}\n' > "$R/app/build.gradle.kts"; ( cd "$R" && git add -A && git commit -qm noenv ) >/dev/null
  change_bar "$R/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h07)" "$H"; expect_code 0; expect_out "게이트가 꺼져 있습니다"
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h07)" "$H"; expect_code 0; expect_empty
fi

tc TC-H08 "Java 판 환경(gradle/ai-test.gradle)만 있으면 이 게이트는 꺼져 있다고 알린다"
if on; then
  R="$(repo h08)"; printf 'plugins {\n    kotlin("jvm")\n}\n' > "$R/app/build.gradle.kts"; mkdir -p "$R/gradle"; echo '// ai-test' > "$R/gradle/ai-test.gradle"
  ( cd "$R" && git add -A && git commit -qm java-env ) >/dev/null
  change_bar "$R/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h08)" "$H"; expect_code 0; expect_out "kotlin-spring-aitest-coverage: @AiTest 환경"
fi

tc TC-H09 "소비 모듈을 모르는 main 변경에 aiTest diff 가 없으면 막는다 (C-04)"
if on; then
  R="$(repo h09)"; change_bar "$R/$CALC" com.ex.core PriceCalculator Service
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h09)" "$H"; expect_code 2; expect_out "소비 모듈을 특정할 수 없는"; expect_out "libraryModules"
fi

tc TC-H10 "소비 모듈을 모르는 main 변경이어도 aiTest diff 가 있으면 통과한다 (C-04)"
if on; then
  R="$(repo h10)"; change_bar "$R/$CALC" com.ex.core PriceCalculator Service
  aitest_for "$R/app/src/aiTest/kotlin/com/ex/app/PriceAiTest.kt" PriceCalculator
  fresh_report "$R/app/$REPORT" com/ex/core PriceCalculator 0 0
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h10)" "$H"; expect_code 0
fi

tc TC-H11 "테스트만 바뀌면 막지 않는다"
if on; then
  R="$(repo h11)"; aitest_for "$R/$FOO_AITEST" x
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h11)" "$H"; expect_code 0; expect_empty
fi

tc TC-H12 "하위 디렉터리에서 호출해도 저장소 루트 기준으로 본다"
if on; then
  R="$(repo h12)"; change_bar "$R/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R/app" run_in "$(hook_in h12)" "$H"; expect_code 2
fi

tc TC-H13 "요청 안에서 커밋한 Controller 변경도 본다 (C-05)"
if on; then
  R="$(repo h13)"; CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h13)" "$H" snapshot
  change_bar "$R/$FOO" com.ex.app FooController
  git -C "$R" commit -qam change
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h13)" "$H"; expect_code 2; expect_out "완료 보류(kotlin-spring-aitest-coverage)"
fi

tc TC-H14 "요청 시작 때 원격 기본 브랜치에 있던 커밋은 요청 안에서 합쳐도 이번 변경이 아니다 (C-05)"
if on; then
  R="$(repo h14)"; git init -q --bare -b main "$TMP/h14-origin.git"
  git -C "$R" remote add origin "$TMP/h14-origin.git"; git -C "$R" push -q -u origin main
  git clone -q -b main "$TMP/h14-origin.git" "$TMP/h14-other"
  change_bar "$TMP/h14-other/$FOO" com.ex.app FooController
  git -C "$TMP/h14-other" -c user.email=o@o -c user.name=o commit -qam other; git -C "$TMP/h14-other" push -q origin main
  git -C "$R" fetch -q
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h14)" "$H" snapshot
  git -C "$R" merge -q --ff-only origin/main
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h14)" "$H"; expect_code 0; expect_empty
fi

tc TC-H15 "요청 안에서 커밋하고 원격 기본 브랜치로 push 해도 막는다 (C-05)"
if on; then
  R="$(repo h15)"; git -C "$R" update-ref refs/remotes/origin/main HEAD
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h15)" "$H" snapshot
  change_bar "$R/$FOO" com.ex.app FooController
  git -C "$R" commit -qam change; git -C "$R" update-ref refs/remotes/origin/main HEAD
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h15)" "$H"; expect_code 2; expect_out "완료 보류(kotlin-spring-aitest-coverage)"
fi

tc TC-H16 "요청 시작 HEAD 를 amend 해도 막는다 (C-05)"
if on; then
  R="$(repo h16)"; echo y > "$R/README"; git -C "$R" add README; git -C "$R" commit -qm second
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h16)" "$H" snapshot
  change_bar "$R/$FOO" com.ex.app FooController
  git -C "$R" commit -qa --amend -m second2
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h16)" "$H"; expect_code 2; expect_out "완료 보류(kotlin-spring-aitest-coverage)"
fi

tc TC-H17 "amend 가 대상 경로를 건드리지 않으면 막지 않는다 (C-05)"
if on; then
  R="$(repo h17)"; echo y > "$R/README"; git -C "$R" add README; git -C "$R" commit -qm second
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h17)" "$H" snapshot
  git -C "$R" commit -q --amend -m second2
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h17)" "$H"; expect_code 0; expect_empty
fi

tc TC-H18 "git 루트 ≠ Gradle 루트 — Gradle 루트 아래 환경 블록으로 게이트를 켜고 0% 를 막는다 (C-02 · C-06)"
if on; then
  R="$(mono_repo h18)"; B="$R/backend"
  CLAUDE_PROJECT_DIR="$B" run_in "$(hook_in h18)" "$H" snapshot
  change_bar "$B/$FOO" com.ex.app FooController
  aitest_for "$B/$FOO_AITEST" x
  fresh_report "$B/app/$REPORT" com/ex/app FooController 10 0
  CLAUDE_PROJECT_DIR="$B" run_in "$(hook_in h18)" "$H"; expect_code 2; expect_out "below 100%"
fi

tc TC-H19 "Controller 와 그 aiTest 를 지우면 막지 않는다 (C-01)"
if on; then
  R="$(repo h19)"; aitest_for "$R/$FOO_AITEST" x
  git -C "$R" add -A; git -C "$R" commit -qm t
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h19)" "$H" snapshot
  git -C "$R" rm -q "$FOO" "$FOO_AITEST"
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h19)" "$H"; expect_code 0; expect_empty
fi

tc TC-H20 "모듈 디렉터리에서 연 세션이 그 밖의 모듈을 고쳐도 본다 (C-04)"
if on; then
  R="$(repo h20)"; CLAUDE_PROJECT_DIR="$R/app" run_in "$(hook_in h20)" "$H" snapshot
  change_bar "$R/$CALC" com.ex.core PriceCalculator Service
  CLAUDE_PROJECT_DIR="$R/app" run_in "$(hook_in h20)" "$H"; expect_code 2; expect_out "$CALC"
fi

tc TC-H21 "요청 전에 커밋한 Controller 를 요청 안에서 메시지만 amend 하면 막지 않는다 (C-05)"
if on; then
  R="$(repo h21)"; change_bar "$R/$FOO" com.ex.app FooController
  git -C "$R" commit -qam before; git -C "$R" update-ref refs/remotes/origin/main HEAD~1
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h21)" "$H" snapshot
  git -C "$R" commit -q --amend -m before2
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h21)" "$H"; expect_code 0; expect_empty
fi

tc TC-H22 "요청 전 Controller 커밋을 amend 하며 대상 밖 파일만 더하면 막지 않는다 (C-05)"
if on; then
  R="$(repo h22)"; change_bar "$R/$FOO" com.ex.app FooController
  git -C "$R" commit -qam before; git -C "$R" update-ref refs/remotes/origin/main HEAD~1
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h22)" "$H" snapshot
  echo r > "$R/README"; git -C "$R" add README; git -C "$R" commit -q --amend -m before2
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h22)" "$H"; expect_code 0; expect_empty
fi

tc TC-H23 "요청 전 받아둔 원격 위로 요청 안에서 리베이스하면 원격 변경도 이전 커밋도 막지 않는다 (C-05)"
if on; then
  R="$(repo h23)"; git -C "$R" checkout -qb feat
  change_bar "$R/$FOO" com.ex.app FooController; git -C "$R" commit -qam feat
  git -C "$R" checkout -q main; change_bar "$R/$CALC" com.ex.core PriceCalculator Service
  git -C "$R" commit -qam remote; git -C "$R" update-ref refs/remotes/origin/main HEAD; git -C "$R" checkout -q feat
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h23)" "$H" snapshot
  git -C "$R" rebase -q origin/main
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h23)" "$H"; expect_code 0; expect_empty
fi

tc TC-H24 "요청 전 받아둔 원격을 요청 안에서 merge 커밋으로 합쳐도 원격 변경은 막지 않는다 (C-05)"
if on; then
  R="$(repo h24)"; git -C "$R" checkout -qb feat; git -C "$R" commit -q --allow-empty -m e; git -C "$R" checkout -q main
  change_bar "$R/$FOO" com.ex.app FooController
  git -C "$R" commit -qam remote; git -C "$R" update-ref refs/remotes/origin/main HEAD; git -C "$R" checkout -q feat
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h24)" "$H" snapshot
  git -C "$R" merge -q --no-edit origin/main
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h24)" "$H"; expect_code 0; expect_empty
fi

tc TC-H25 "jq 가 없어도 막는다"
if on; then
  R="$(repo h25)"; NJ="$(nojq_path)"; PATH="$NJ" command -v jq >/dev/null && fail_tc "PATH 에 jq 가 남아 있음"
  PATH="$NJ" CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h25)" "$H" snapshot
  change_bar "$R/$FOO" com.ex.app FooController
  PATH="$NJ" CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h25)" "$H"; expect_code 2; expect_out "완료 보류(kotlin-spring-aitest-coverage)"
fi

tc TC-H26 "jq 가 없어도 stop_hook_active 를 읽고 systemMessage 를 올바른 JSON 으로 낸다 (C-08)"
if on; then
  R="$(repo h26)"; NJ="$(nojq_path)"; change_bar "$R/$FOO" com.ex.app FooController
  PATH="$NJ" CLAUDE_PROJECT_DIR="$R" run_in '{ "session_id" : "h26", "stop_hook_active" : true }' "$H"; expect_code 0
  printf '%s' "$OUT" | jq -er .systemMessage | grep -qF "트랩 방지" || fail_tc "systemMessage JSON 이 아니거나 내용이 다름"
  printf 'plugins {\n    kotlin("jvm")\n}\n' > "$R/app/build.gradle.kts"; ( cd "$R" && git add -A app/build.gradle.kts && git commit -qm noenv ) >/dev/null
  PATH="$NJ" CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h26)" "$H"; expect_code 0
  printf '%s' "$OUT" | jq -er .systemMessage | grep -qF '"Kotlin AiTest 환경 만들어줘"' || fail_tc "환경 없음 systemMessage 의 따옴표가 깨짐"
fi

tc TC-H27 "상태 · ACK 는 Gradle 루트의 .claude/kotlin-spring-aitest-coverage/ 에 두고 git status 에 나오지 않는다"
if on; then
  R="$(mono_repo h27)"; B="$R/backend"
  CLAUDE_PROJECT_DIR="$B" run_in "$(hook_in h27)" "$H" snapshot
  [ -f "$(state_of "$B")/h27.base" ] && [ -f "$(state_of "$B")/h27.turn" ] || fail_tc "상태 파일이 $(state_of "$B") 에 없음"
  [ -z "$(git -C "$R" status --porcelain)" ] || fail_tc "git status 가 깨끗하지 않음: $(git -C "$R" status --porcelain)"
  change_bar "$B/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$B" run_in "$(hook_in h27)" "$H"; expect_code 2; expect_out "backend/.claude/kotlin-spring-aitest-coverage/h27.ack"
fi

tc TC-H28 "Gradle Kotlin DSL 이 아니면 조용히 통과하고 상태를 만들지 않는다"
if on; then
  R="$(repo h28)"; ( cd "$R" && git mv settings.gradle.kts settings.gradle && git commit -qm groovy ) >/dev/null
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h28)" "$H" snapshot
  change_bar "$R/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h28)" "$H"; expect_code 0; expect_empty
  [ -e "$R/.claude" ] && fail_tc ".claude 가 생겼음"
fi

tc TC-H29 "판정 도구(javap)가 없으면 막는다 (C-09)"
if on; then
  R="$(repo h29)"; change_bar "$R/$FOO" com.ex.app FooController
  aitest_for "$R/$FOO_AITEST" x
  fresh_report "$R/app/$REPORT" com/ex/app FooController 0 0
  AITEST_JAVAP="$TMP/no-javap" CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h29)" "$H"; expect_code 2; expect_out "C-09"
fi

tc TC-H30 "아직 커밋하지 않은 환경 블록도 환경으로 본다"
if on; then
  R="$(repo h30)"; printf 'plugins {\n    kotlin("jvm")\n}\n' > "$R/app/build.gradle.kts"; ( cd "$R" && git add -A && git commit -qm noenv ) >/dev/null
  printf '%s\n' "$MARKER_BLOCK" >> "$R/app/build.gradle.kts"
  change_bar "$R/$FOO" com.ex.app FooController
  CLAUDE_PROJECT_DIR="$R" run_in "$(hook_in h30)" "$H"; expect_code 2; expect_out "완료 보류(kotlin-spring-aitest-coverage)"
fi

flush_tc; echo "== ensure-docker-for-aitest.sh (템플릿)"

# 템플릿을 채우고 docker · colima · open 을 호출만 남기는 스텁으로 바꾼다. $1=이름 $2=데몬이 처음부터 떠 있으면 1 → 디렉터리 출력
ensure_env() {
  local e="$TMP/$1"
  rm -rf "$e"; mkdir -p "$e/bin" "$e/home"
  sed 's/{{IMAGES}}/  "mysql:8.0"/' "$E_TMPL" > "$e/ensure.sh"; chmod +x "$e/ensure.sh"
  [ "${2:-0}" = 1 ] && : > "$e/up"
  printf '#!/bin/sh\necho "docker $*" >> "%s/calls"\ncase "$1" in info) [ -f "%s/up" ];; *) exit 0;; esac\n' "$e" "$e" > "$e/bin/docker"
  printf '#!/bin/sh\necho "colima $*" >> "%s/calls"\ncase "$1" in status) exit 1;; start) : > "%s/up";; esac\n' "$e" "$e" > "$e/bin/colima"
  printf '#!/bin/sh\necho "open $*" >> "%s/calls"\n' "$e" > "$e/bin/open"
  chmod +x "$e/bin/"*
  echo "$e"
}

tc TC-E01 "데몬이 이미 응답하면 기동 · context 변경 · ~/.testcontainers.properties 수정을 하지 않는다"
if on; then
  E="$(ensure_env e01 1)"
  HOME="$E/home" PATH="$E/bin:$PATH" AITEST_DOCKER_WAIT_SEC=4 run "$E/ensure.sh"; expect_code 0
  OUT="$(cat "$E/calls")"; expect_not "colima start"; expect_not "docker context"; expect_not "open "; expect_out "docker run --rm hello-world"
  [ -e "$E/home/.testcontainers.properties" ] && fail_tc "~/.testcontainers.properties 가 생겼음"
fi

tc TC-E02 "데몬이 없으면 colima 를 띄우고 reuse 설정을 만든다"
if on; then
  E="$(ensure_env e02 0)"
  HOME="$E/home" PATH="$E/bin:$PATH" AITEST_DOCKER_WAIT_SEC=4 run "$E/ensure.sh"; expect_code 0
  grep -q 'reuse.enable=true' "$E/home/.testcontainers.properties" 2>/dev/null || fail_tc "reuse 설정이 없음"
  OUT="$(cat "$E/calls")"; expect_out "colima start"; expect_out "docker context use colima"
fi

flush_tc
echo
printf '통과 %d / 실패 %d' "$PASS" "$FAIL"
[ "$SKIP" -gt 0 ] && printf ' / 건너뜀 %d' "$SKIP"
echo
[ "$FAIL" = 0 ] || exit 1
