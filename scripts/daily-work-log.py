#!/usr/bin/env python3
"""
每日工作打标脚本——收集当天活动，按时段生成日报，在已有 Issue Tracker issue 上打标。

数据源：
  1. Git 提交（多仓库，按时间线）——最可靠
  2. Obsidian 人区文件改动（按 30 分钟窗口聚合，不逐文件记录）
  3. Loop 运行记录
  4. 飞书日历会议（daily-schedule.sh 已同步）
  5. 手动补录（--manual-file JSON）

FUZ 关联来源（优先级降序）：
  1. 手动补录里的显式 fuz 字段
  2. Git commit message 里的 ISSUE-xxx
  3. fuz-map.json 关键词映射
  不从 Obsidian 文件名提取 FUZ（案例文档名含 FUZ 不等于在做那个 issue）

用法：
  python3 daily-work-log.py                              # 今天 dry-run
  python3 daily-work-log.py --commit                     # 今天，写 Issue Tracker
  python3 daily-work-log.py --date 2026-07-13            # 指定日期
  python3 daily-work-log.py --manual-file ~/today.json   # 补录手动活动
"""

import argparse, os, re, json, subprocess, datetime, collections

# === 配置 ===
GIT_REPOS = {
    "holo-project": "/mnt/d/JAVA/holo-project",
    "ai-loop": "~/JAVA/ai/ai-loop",
    "tiandao": "/mnt/d/JAVA/knowledge/tiandao",
}
LOOP_RUNS = "~/JAVA/ai/ai-loop/runs"
OBSIDIAN_VAULT = "/mnt/d/JAVA/knowledge/tiandao"
DAILY_REPORT_DIR = os.path.join(OBSIDIAN_VAULT, "00-首页/日报")
SCHEDULE_DIR = os.path.join(OBSIDIAN_VAULT, "99-generated/daily-schedule")
ISSUE_MAP_FILE = os.path.expanduser("~/.config/daily-work-log/fuz-map.json")

# 人区目录
HUMAN_DIRS = {
    "00-首页", "00-inbox", "00-human", "00-core-view",
    "10-mocs", "20-goals", "20-work-delivery",
    "30-projects", "30-handoff", "30-reviews",
    "90-sources", "08-模板",
}

# 工作类型分类
WORK_CATEGORIES = [
    ("线上问题", re.compile(r"P0|P1|告警|稳定性|NPE|ClassCast|空值|降级|FaultCache|lifecycle|SLA|线上|故障|应急", re.I)),
    ("技术方案", re.compile(r"技术方案|tech.?design|BPR|评审|方案|spec|MIT|接口|契约|DDL", re.I)),
    ("会议", re.compile(r"会议|评审|站会|周会|对齐|sync", re.I)),
    ("B站自动化", re.compile(r"bili|digest|whisper|音频|稍后再看|收藏|cron|bilibili", re.I)),
    ("Obsidian治理", re.compile(r"obsidian|vault|MOC|图谱|断链|归档|frontmatter|AI.?味|人味|墨衡|人格|人区|隔离", re.I)),
    ("代码编写", re.compile(r"feat|fix|refactor|chore|build|impl|add|update|CR|review|commit|merge|test", re.I)),
]

ISSUE_RE = re.compile(r'ISSUE-(\d+)')


def run_cmd(cmd, cwd=None, timeout=10):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd, timeout=timeout)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


def categorize(text):
    for cat, pattern in WORK_CATEGORIES:
        if pattern.search(text):
            return cat
    return "其他"


def load_issue_map():
    if not os.path.isfile(ISSUE_MAP_FILE):
        return {}
    try:
        with open(ISSUE_MAP_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {}


def lookup_issue_by_keyword(text, issue_map):
    """通过 fuz-map 关键词映射查找 FUZ"""
    result = []
    for keyword, issue_id in issue_map.items():
        if issue_id and keyword.lower() in text.lower():
            issue_num = issue_id.replace('ISSUE-', '')
            if issue_num not in result:
                result.append(issue_num)
    return result


def collect_git_commits(date_str, issue_map):
    commits = []
    next_day = (datetime.date.fromisoformat(date_str) + datetime.timedelta(days=1)).isoformat()
    for name, path in GIT_REPOS.items():
        if not os.path.isdir(path):
            continue
        log = run_cmd(
            f'git log --since="{date_str} 00:00" --until="{next_day} 00:00" '
            f'--format="%H|%ai|%s" --all',
            cwd=path
        )
        for line in log.split('\n'):
            if not line.strip():
                continue
            parts = line.split('|', 2)
            if len(parts) < 3:
                continue
            hash_, timestamp, msg = parts
            try:
                dt = datetime.datetime.fromisoformat(timestamp.split(' +')[0])
            except Exception:
                continue
            issue_list = ISSUE_RE.findall(msg)
            if not issue_list:
                issue_list = lookup_issue_by_keyword(msg, issue_map)
            commits.append({
                'time': dt,
                'repo': name,
                'message': msg,
                'fuz': issue_list,
            })
    commits.sort(key=lambda x: x['time'])
    return commits


def collect_obsidian_changes(date_str):
    """收集 Obsidian 人区改动，按 30 分钟窗口聚合"""
    target_date = datetime.date.fromisoformat(date_str)
    raw_files = []
    for root, dirs, files in os.walk(OBSIDIAN_VAULT):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        rel = os.path.relpath(root, OBSIDIAN_VAULT)
        if rel == '.':
            continue
        top = rel.split('/')[0]
        if top not in HUMAN_DIRS:
            dirs[:] = []
            continue
        for f in files:
            if not f.endswith('.md'):
                continue
            path = os.path.join(root, f)
            try:
                mtime = datetime.datetime.fromtimestamp(os.path.getmtime(path))
                if mtime.date() == target_date:
                    raw_files.append({
                        'time': mtime,
                        'file': os.path.relpath(path, OBSIDIAN_VAULT),
                        'dir': top,
                    })
            except Exception:
                continue

    raw_files.sort(key=lambda x: x['time'])

    # 按 30 分钟窗口聚合
    windows = []
    current = None
    for f in raw_files:
        if current is None or (f['time'] - current['start_time']).total_seconds() > 1800:
            if current:
                windows.append(current)
            current = {
                'start_time': f['time'],
                'end_time': f['time'],
                'files': [f],
            }
        else:
            current['end_time'] = max(current['end_time'], f['time'])
            current['files'].append(f)
    if current:
        windows.append(current)

    # 转为活动
    activities = []
    for w in windows:
        dirs_involved = collections.Counter(f['dir'] for f in w['files'])
        dir_summary = ', '.join(f"{d}({n})" for d, n in dirs_involved.most_common(3))
        combined_text = ' '.join(f['file'] for f in w['files'])
        cat = categorize(combined_text)
        # Obsidian 改动不自动关联 FUZ——文件名太杂，误报率高
        activities.append({
            'time': w['start_time'],
            'category': 'Obsidian治理',
            'desc': f"Obsidian: {len(w['files'])} 文件 ({dir_summary})",
            'fuz': [],
        })
    return activities, len(raw_files)


def collect_loop_runs(date_str):
    target_date = datetime.date.fromisoformat(date_str)
    runs = []
    if not os.path.isdir(LOOP_RUNS):
        return runs
    for d in os.listdir(LOOP_RUNS):
        path = os.path.join(LOOP_RUNS, d)
        if not os.path.isdir(path):
            continue
        try:
            mtime = datetime.datetime.fromtimestamp(os.path.getmtime(path))
            if mtime.date() == target_date:
                runs.append({'time': mtime, 'run': d})
        except Exception:
            continue
    runs.sort(key=lambda x: x['time'])
    return runs


def collect_meetings(date_str):
    meetings = []
    sched_file = os.path.join(SCHEDULE_DIR, f"{date_str}.md")
    if not os.path.isfile(sched_file):
        return meetings
    with open(sched_file, 'r', encoding='utf-8') as f:
        content = f.read()
    for m in re.finditer(r'\|\s*(\d{2}:\d{2})-(\d{2}:\d{2})\s*\|\s*([^|]+)\s*\|', content):
        start, end, summary = m.groups()
        summary = summary.strip()
        if not summary or not any(k in summary for k in ('会议', '会', '评审')):
            continue
        try:
            dt = datetime.datetime.fromisoformat(f"{date_str}T{start}:00")
        except Exception:
            continue
        meetings.append({'time': dt, 'summary': summary, 'end': end})
    return meetings


def collect_manual(date_str, manual_file):
    if not manual_file or not os.path.isfile(manual_file):
        return []
    try:
        with open(manual_file, 'r', encoding='utf-8') as f:
            entries = json.load(f)
    except Exception as e:
        print(f"⚠ 手动补录文件解析失败: {e}")
        return []
    activities = []
    for e in entries:
        try:
            start = e['start']
            end = e.get('end', start)
            dt = datetime.datetime.fromisoformat(f"{date_str}T{start}:00")
            activities.append({
                'time': dt,
                'category': e.get('category', '其他'),
                'desc': e.get('desc', ''),
                'fuz': [str(x) for x in e.get('fuz', [])],
            })
        except Exception:
            continue
    return activities


def build_timeline(commits, obsidian_acts, runs, meetings, manual):
    timeline = []

    for c in commits:
        cat = categorize(c['message'])
        timeline.append({
            'category': cat,
            'desc': f"[{c['repo']}] {c['message']}",
            'fuz': c['fuz'],
            'time': c['time'],
        })

    timeline.extend(obsidian_acts)

    for r in runs:
        timeline.append({
            'category': '代码编写',
            'desc': f"Loop: {r['run']}",
            'fuz': [],
            'time': r['time'],
        })

    for m in meetings:
        timeline.append({
            'category': '会议',
            'desc': m['summary'],
            'fuz': [],
            'time': m['time'],
        })

    timeline.extend(manual)
    timeline.sort(key=lambda x: x['time'])
    return timeline


def merge_time_blocks(timeline):
    """将时间相近的活动合并为时段块"""
    if not timeline:
        return []

    blocks = []
    current = None

    for act in timeline:
        if current is None:
            current = _new_block(act)
            continue

        gap = (act['time'] - current['end_time']).total_seconds() / 60
        same_cat = act['category'] == current['category']
        same_fuz = set(act['fuz']) == current['fuz_set'] or (not act['fuz'] and not current['fuz_set'])

        # 合并条件：同类别 + (同FUZ或都无FUZ) + 间隔 ≤ 45 分钟
        if same_cat and same_fuz and gap <= 45:
            current['end_time'] = max(current['end_time'], act['time'])
            current['issue_list'].extend(act['fuz'])
            if act['desc'] not in current['descs']:
                current['descs'].append(act['desc'])
            current['count'] += 1
        else:
            blocks.append(_finalize_block(current))
            current = _new_block(act)

    if current:
        blocks.append(_finalize_block(current))

    return blocks


def _new_block(act):
    return {
        'start_time': act['time'],
        'end_time': act['time'],
        'category': act['category'],
        'issue_list': list(act['fuz']),
        'fuz_set': set(act['fuz']),
        'descs': [act['desc']],
        'count': 1,
    }


def _finalize_block(b):
    if len(b['descs']) <= 2:
        desc = '; '.join(b['descs'])
    else:
        desc = f"{b['descs'][0]} 等 {b['count']} 项"
    return {
        'start': b['start_time'].strftime('%H:%M'),
        'end': b['end_time'].strftime('%H:%M'),
        'category': b['category'],
        'fuz': sorted(set(b['issue_list'])),
        'desc': desc,
    }


def generate_report(date_str, blocks, raw_counts):
    all_issues = set()
    cat_counts = collections.Counter()

    for b in blocks:
        all_issues.update(b['fuz'])
        cat_counts[b['category']] += 1

    lines = [
        "---",
        f"文档标题: 日报｜{date_str}",
        "文档类型: 每日报告",
        f"创建日期: {date_str}",
        "---",
        "",
        f"# 日报｜{date_str}",
        "",
        f"> Git {raw_counts['git']} | Obsidian {raw_counts['obsidian']} 文件→{raw_counts['obsidian_windows']} 窗口 | Loop {raw_counts['loop']} | 会议 {raw_counts['meetings']} | 手动 {raw_counts['manual']}",
        f"> 合并为 {len(blocks)} 个时段。",
        "",
        "## 时间线（按时段）",
        "",
        "| 时段 | 类型 | 工作内容 | 关联Issue |",
        "|------|------|---------|----------|",
    ]

    for b in blocks:
        issue_str = ', '.join(f'ISSUE-{f}' for f in b['fuz']) if b['fuz'] else '—'
        lines.append(f"| {b['start']}–{b['end']} | {b['category']} | {b['desc']} | {issue_str} |")

    lines.append("")
    lines.append("## 工作类型分布")
    lines.append("")
    lines.append("| 类型 | 时段数 |")
    lines.append("|------|--------|")
    for cat, cnt in cat_counts.most_common():
        lines.append(f"| {cat} | {cnt} |")

    lines.append("")
    lines.append("## 关联 Issue Tracker Issue")
    lines.append("")
    if all_issues:
        for fuz in sorted(all_issues, key=lambda x: int(x)):
            lines.append(f"- ISSUE-{fuz}")
    else:
        lines.append("- （无关联 issue）")

    lines.append("")
    lines.append("## 链接")
    lines.append("")
    lines.append("- [[今日看板]]")

    return '\n'.join(lines), all_issues


def _calc_duration(start, end):
    try:
        s = datetime.datetime.strptime(start, '%H:%M')
        e = datetime.datetime.strptime(end, '%H:%M')
        delta = (e - s).total_seconds() / 3600
        return max(delta, 0.25)
    except Exception:
        return 0.5


def post_to_issue_tracker(date_str, blocks, dry_run=True):
    if dry_run:
        print("\n=== Issue Tracker 打标（DRY RUN）===")
    else:
        print("\n=== Issue Tracker 打标 ===")

    issue_blocks = collections.defaultdict(list)
    no_issue = []

    for b in blocks:
        if b['fuz']:
            for fuz in b['fuz']:
                issue_blocks[f"ISSUE-{fuz}"].append(b)
        else:
            no_issue.append(b)

    if not issue_blocks:
        print("  （无关联 issue 的活动，仅记入日报）")
        if no_issue:
            for b in no_issue:
                print(f"    {b['start']}–{b['end']} [{b['category']}] {b['desc']}")
        return

    for issue_id, fuz_acts in sorted(issue_blocks.items()):
        lines = [
            f"**每日工作打标｜{date_str}**",
            "",
            "| 时段 | 类型 | 工作内容 |",
            "|------|------|---------|",
        ]
        for b in fuz_acts:
            lines.append(f"| {b['start']}–{b['end']} | {b['category']} | {b['desc']} |")

        total_hours = sum(_calc_duration(b['start'], b['end']) for b in fuz_acts)
        lines.append(f"\n工时：约 {total_hours:.1f}h（{len(fuz_acts)} 个时段）")

        content = '\n'.join(lines)

        if dry_run:
            print(f"\n  → {issue_id}:")
            for line in content.split('\n'):
                print(f"    {line}")
        else:
            try:
                proc = subprocess.run(
                    ['legacy-tracker', 'issue', 'comment', 'add', issue_id, '--content-stdin'],
                    input=content, capture_output=True, text=True, timeout=15
                )
                if proc.returncode == 0:
                    print(f"  ✅ {issue_id}: comment posted")
                else:
                    print(f"  ❌ {issue_id}: {proc.stderr.strip()}")
            except Exception as e:
                print(f"  ❌ {issue_id}: {e}")

    if no_issue:
        print(f"\n  （{len(no_issue)} 个时段无关联 issue，仅记入日报）")
        for b in no_issue:
            print(f"    {b['start']}–{b['end']} [{b['category']}] {b['desc']}")


def main():
    parser = argparse.ArgumentParser(description='每日工作打标')
    parser.add_argument('--date', default=datetime.date.today().isoformat())
    parser.add_argument('--commit', action='store_true', help='实际写 Issue Tracker')
    parser.add_argument('--manual-file', help='手动补录 JSON 文件')
    args = parser.parse_args()

    date_str = args.date
    dry_run = not args.commit

    print(f"=== 每日工作打标｜{date_str} ===")
    print(f"模式: {'DRY RUN' if dry_run else 'COMMIT'}")
    print()

    issue_map = load_issue_map()

    commits = collect_git_commits(date_str, issue_map)
    obsidian_acts, obsidian_file_count = collect_obsidian_changes(date_str)
    runs = collect_loop_runs(date_str)
    meetings = collect_meetings(date_str)
    manual = collect_manual(date_str, args.manual_file)

    raw_counts = {
        'git': len(commits),
        'obsidian': obsidian_file_count,
        'obsidian_windows': len(obsidian_acts),
        'loop': len(runs),
        'meetings': len(meetings),
        'manual': len(manual),
    }

    print(f"Git 提交: {raw_counts['git']}")
    print(f"Obsidian 人区: {obsidian_file_count} 文件 → {len(obsidian_acts)} 窗口")
    print(f"Loop 运行: {raw_counts['loop']}")
    print(f"会议: {raw_counts['meetings']}")
    print(f"手动补录: {raw_counts['manual']}")
    print(f"FUZ 映射: {len(issue_map)} 条")
    print()

    timeline = build_timeline(commits, obsidian_acts, runs, meetings, manual)
    blocks = merge_time_blocks(timeline)

    print(f"合并时段: {len(blocks)}")
    print()

    report, all_issues = generate_report(date_str, blocks, raw_counts)

    os.makedirs(DAILY_REPORT_DIR, exist_ok=True)
    report_path = os.path.join(DAILY_REPORT_DIR, f"{date_str}.md")
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(report)
    print(f"✓ 日报已写入: {report_path}")

    post_to_issue_tracker(date_str, blocks, dry_run)

    print(f"\n=== 摘要 ===")
    print(f"关联 Issue: {', '.join(f'ISSUE-{x}' for x in sorted(all_issues, key=int)) if all_issues else '无'}")
    print(f"日报路径: {report_path}")


if __name__ == '__main__':
    main()
