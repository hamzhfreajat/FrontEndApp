import os, re

filepath = r'd:\open\classifieds-app\frontend\lib\screens\categories_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

new_logic = '''
          if (widget.parentId != null) {
            final displayCategories = allCategories.where((c) => c.parentId == widget.parentId).toList();
            displayCategories.sort((a, b) => b.adsCount.compareTo(a.adsCount));

            if (displayCategories.isEmpty) {
              return const Center(child: Text('?? ???? ????? ?????', style: TextStyle(fontSize: 16, color: Colors.grey)));
            }

            return GridView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: displayCategories.length,
              itemBuilder: (context, index) {
                return _buildCategoryCard(context, displayCategories[index], allCategories);
              },
            );
          } else {
            final sections = [
              {'id': 3, 'title': '?????? ???????'},
              {'id': 2, 'title': '?????? ?????'},
              {'id': 10313, 'title': '?????'},
            ];
            
            return ListView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.symmetric(vertical: 24),
              itemCount: sections.length,
              itemBuilder: (context, sectionIndex) {
                 final sectionId = sections[sectionIndex]['id'] as int;
                 final sectionTitle = sections[sectionIndex]['title'] as String;
                 
                 final sectionCats = allCategories.where((c) => c.parentId == sectionId).toList();
                 if (sectionCats.isEmpty) return const SizedBox.shrink();
                 sectionCats.sort((a, b) => b.adsCount.compareTo(a.adsCount));
                 
                 return Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                       child: Text(
                         sectionTitle,
                         style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                       ),
                     ),
                     GridView.builder(
                       shrinkWrap: true,
                       physics: const NeverScrollableScrollPhysics(),
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                         crossAxisCount: 3,
                         childAspectRatio: 0.85,
                         crossAxisSpacing: 12,
                         mainAxisSpacing: 16,
                       ),
                       itemCount: sectionCats.length,
                       itemBuilder: (context, index) {
                         return _buildCategoryCard(context, sectionCats[index], allCategories);
                       }
                     ),
                     const SizedBox(height: 16),
                   ]
                 );
              }
            );
          }
'''

new_method = '''
  Widget _buildCategoryCard(BuildContext context, Category cat, List<Category> allCategories) {
    final catColor = _getColor(cat.colorHex);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryDetailsPage(
              category: cat,
              allCategories: allCategories,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: (() {
                final imageUrl = ApiService.resolveIconUrl(cat.iconName);
                if (imageUrl != null) {
                  return ClipOval(
                    child: ApiService.buildIconImage(
                      imageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      fallback: EmojiCategoryIcon(
                        iconName: cat.iconName,
                        size: 32,
                        color: catColor,
                      ),
                    ),
                  );
                }
                return EmojiCategoryIcon(
                  iconName: cat.iconName,
                  size: 32,
                  color: catColor,
                );
              })(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                cat.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black87,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (cat.adsCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                "$" + "{cat.adsCount} ?????",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
'''

content = re.sub(
    r'final displayCategories = widget\.parentId != null.*?return grid;\n  }\n}',
    new_logic + '''
        },
      ),
    );

    if (widget.parentId != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: const Color(0xFF0075FF),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: grid,
      );
    }

    return grid;
  }
''' + new_method,
    content,
    flags=re.DOTALL
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
