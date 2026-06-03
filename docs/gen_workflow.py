import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch

fig, ax = plt.subplots(figsize=(16, 9))
ax.set_xlim(0, 16.5)
ax.set_ylim(0, 9)
ax.axis('off')
fig.patch.set_facecolor('#F0F4F8')

FONT = 'Arial Unicode MS'

# ── helpers ──────────────────────────────────────────────────
def rbox(x, y, w, h, label, sub=None, fc='#FFF', ec='#555',
         lw=1.6, fs=11, sfs=9, bold=False):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0.07',
                                facecolor=fc, edgecolor=ec, linewidth=lw, zorder=3))
    dy = 0.13 if sub else 0
    ax.text(x+w/2, y+h/2+dy, label, ha='center', va='center',
            fontsize=fs, fontweight='bold' if bold else 'normal',
            color='#1A1A2E', fontfamily=FONT, zorder=4)
    if sub:
        ax.text(x+w/2, y+h/2-dy-0.02, sub, ha='center', va='center',
                fontsize=sfs, color='#55667A', fontfamily=FONT, zorder=4)

def arr(x1, y1, x2, y2):
    ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle='->', color='#7A8AA0', lw=1.8,
                                connectionstyle='arc3,rad=0.0'), zorder=5)

def lane(x, y, w, h, label, fc, alpha=0.15):
    """Colored background + left-strip rotated label."""
    # background
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0.1',
                                facecolor=fc, edgecolor='none', alpha=alpha, zorder=1))
    # left strip
    ax.add_patch(FancyBboxPatch((x, y), 0.55, h, boxstyle='round,pad=0.05',
                                facecolor=fc, edgecolor='none', alpha=0.55, zorder=2))
    # rotated label in strip
    ax.text(x+0.28, y+h/2, label, ha='center', va='center', fontsize=8,
            color='#ffffff', fontfamily=FONT, fontweight='bold',
            rotation=90, zorder=3)

# ── Title ─────────────────────────────────────────────────────
ax.text(8.4, 8.68, 'M3U8DownloadDemo  核心工作流程',
        ha='center', va='center', fontsize=17, fontweight='bold',
        color='#1A1A2E', fontfamily=FONT)

# ══ Row A  App 层   y: 7.0–8.45 ═════════════════════════════
lane(0.3, 7.0, 15.9, 1.45, 'App 层', '#1976D2')

rbox(1.1, 7.18, 3.8, 1.0, 'URL 输入',
     sub='Index.ets  ·  TaskStore 持久化',
     fc='#DDEEFF', ec='#1976D2', bold=True)

arr(4.9, 7.68, 5.5, 7.68)

rbox(5.5, 7.18, 5.3, 1.0, 'TaskQueue  并发调度',
     sub='最多 3 个任务同时下载  ·  pause / resume / delete',
     fc='#DDEEFF', ec='#1976D2', bold=True)

arr(10.8, 7.68, 11.4, 7.68)

rbox(11.4, 7.18, 4.5, 1.0, 'ijkplayer  播放器',
     sub='PlayerPage.ets  ·  读取 httpMovie.m3u8',
     fc='#DDEEFF', ec='#1976D2', bold=True)

arr(8.15, 7.18, 8.15, 6.72)   # TaskQueue -> Manager

# ══ Row B  Library 门面   y: 5.7–7.0 ════════════════════════
lane(0.3, 5.7, 15.9, 1.3, '门面层', '#00897B')

rbox(1.1, 5.9, 14.1, 0.82, 'M3U8Manager（单例门面）',
     sub='setup()  ·  download()  ·  pause()  ·  resume()  ·  delete()   <--  DownloadProgressHandler / DownloadCompleteHandler',
     fc='#E0F2F1', ec='#00897B', bold=True, fs=12, sfs=9)

arr(8.15, 5.9, 8.15, 5.45)    # Manager -> Container

# ══ Row C  Download Container   y: 3.3–5.7 ══════════════════
lane(0.3, 3.3, 15.9, 2.4, '下载容器', '#5E35B1')

# dashed container outline
ax.add_patch(FancyBboxPatch((1.0, 3.5), 14.2, 1.82,
                             boxstyle='round,pad=0.06',
                             facecolor='none', edgecolor='#7E57C2',
                             linewidth=1.4, linestyle='--', zorder=2))
ax.text(1.3, 5.2, 'M3U8DownloadContainer  （每个 URL 独立一个）',
        fontsize=9.5, color='#512DA8', fontfamily=FONT, fontweight='bold', zorder=4)

rbox(1.1, 3.65, 4.2, 1.0, 'M3U8Analyser',
     sub='获取 .m3u8  ·  提取 TS 列表 + AES Key URL',
     fc='#EDE7F6', ec='#7E57C2', sfs=9)

arr(5.3, 4.15, 5.85, 4.15)

rbox(5.85, 3.65, 4.5, 1.0, 'M3U8Downloader',
     sub='串行下载 AES Key  +  逐片下载 TS 分片',
     fc='#EDE7F6', ec='#7E57C2', sfs=9)

arr(10.35, 4.15, 10.9, 4.15)

rbox(10.9, 3.65, 4.1, 1.0, 'M3U8FileManager',
     sub='文件 I/O  ·  目录管理  ·  路径计算',
     fc='#EDE7F6', ec='#7E57C2', sfs=9)

arr(8.15, 3.5, 8.15, 3.05)    # Container -> Storage

# ══ Row D  本地文件存储   y: 1.75–3.3 ═══════════════════════
lane(0.3, 1.75, 15.9, 1.55, '文件存储', '#E65100')

rbox(1.1, 1.95, 14.1, 1.1,
     '{saveFilePath}/m3u8files/{md5(url)}/',
     sub='oriMovie.m3u8（原始）  ·  movie.m3u8（本地路径版）  ·  httpMovie.m3u8（HTTP版）  ·  *.ts 分片  ·  AES key 文件',
     fc='#FFF3E0', ec='#E65100', bold=True, fs=12, sfs=9.5)

arr(3.8, 1.95, 3.8, 1.52)     # Storage -> LocalServer

# ══ Row E  本地 HTTP 服务   y: 0.25–1.75 ════════════════════
lane(0.3, 0.25, 8.5, 1.5, 'HTTP服务', '#1565C0')

rbox(1.1, 0.45, 7.4, 1.0, 'M3U8LocalServer',
     sub='TCP HTTP  ·  127.0.0.1:{port}  ·  向播放器提供 TS 分片文件访问',
     fc='#E3F2FD', ec='#1565C0', bold=True, sfs=9)

# LocalServer --bent--> ijkplayer (top-right)
ax.annotate('', xy=(13.65, 7.18), xytext=(8.5, 0.95),
            arrowprops=dict(arrowstyle='->', color='#1565C0', lw=1.8,
                            connectionstyle='angle,angleA=0,angleB=-90'), zorder=5)
ax.text(13.05, 4.1, 'httpMovie.m3u8', fontsize=8.5, color='#1565C0',
        fontfamily=FONT, ha='center', va='center', rotation=90, zorder=5)

# ── Legend ────────────────────────────────────────────────────
patches = [
    mpatches.Patch(color='#1976D2', alpha=0.6, label='App 层（entry）'),
    mpatches.Patch(color='#00897B', alpha=0.6, label='m3u8downloader — 门面'),
    mpatches.Patch(color='#5E35B1', alpha=0.6, label='m3u8downloader — 下载容器'),
    mpatches.Patch(color='#E65100', alpha=0.6, label='本地文件存储'),
    mpatches.Patch(color='#1565C0', alpha=0.6, label='本地 HTTP 服务'),
]
ax.legend(handles=patches, loc='lower right', ncol=5, fontsize=8,
          framealpha=0.85, bbox_to_anchor=(1.0, 0.0),
          prop={'family': FONT, 'size': 8})

plt.tight_layout(pad=0.3)
out = '/Users/wangbinji/Desktop/M3U8DownloadDemo/docs/workflow.png'
plt.savefig(out, dpi=150, bbox_inches='tight', facecolor=fig.get_facecolor())
print(f'saved: {out}')
