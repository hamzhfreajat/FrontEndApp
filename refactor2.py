import os, re

filepath = r'd:\open\classifieds-app\frontend\lib\screens\categories_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace childAspectRatio: 0.85 with childAspectRatio: 0.65 in two places
content = content.replace('childAspectRatio: 0.85,', 'childAspectRatio: 0.65,')

new_method = '''
  String _getImageForCategory(int id) {
    switch (id) {
      // Sale Categories
      case 10310: return 'assets/images/real_estate/sale_house.png';
      case 10311: return 'assets/images/real_estate/sale_commercial.png';
      case 10314: return 'assets/images/real_estate/sale_farm.png';
      case 10315: return 'assets/images/real_estate/sale_resort.png';
      
      // Rent Categories
      case 306: return 'assets/images/real_estate/shared_housing.png';
      case 310: return 'assets/images/real_estate/rent_house.png';
      case 311: return 'assets/images/real_estate/rent_commercial.png';
      case 313: return 'assets/images/real_estate/land_land.png';
      case 314: return 'assets/images/real_estate/land_farm.png';
      case 315: return 'assets/images/real_estate/land_resort.png';
      case 316: return 'assets/images/real_estate/land_country.png';
      
      // Lands Categories
      case 19000: return 'assets/images/real_estate/land_residential.png';
      case 19010: return 'assets/images/real_estate/land_commercial.png';
      case 19020: return 'assets/images/real_estate/land_industrial.png';
      case 19030: return 'assets/images/real_estate/land_agricultural.png';
      case 19040: return 'assets/images/real_estate/land_touristic.png';
      case 19050: return 'assets/images/real_estate/land_mixed.png';
      case 19060: return 'assets/images/real_estate/land_gov.png';
      case 19070: return 'assets/images/real_estate/land_unzoned.png';
      
      default: return 'assets/images/real_estate/house.png';
    }
  }

  Widget _buildCategoryCard(BuildContext context, Category cat, List<Category> allCategories) {
    final imagePath = _getImageForCategory(cat.id);
    
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF8FAFC),
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              cat.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                height: 1.2,
              ),
            ),
          ),
          if (cat.adsCount > 0) ...[
            const SizedBox(height: 2),
            Padding(
               padding: const EdgeInsets.symmetric(horizontal: 4.0),
               child: Text(
                  "$" + "{cat.adsCount} ?????",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
               ),
            ),
          ],
        ],
      ),
    );
  }
}
'''

content = re.sub(
    r'  Widget _buildCategoryCard\(BuildContext context.*?}\n}\n',
    new_method,
    content,
    flags=re.DOTALL
)

# Fix the string interpolation parsing bug statically:
content = content.replace('"$" + "{cat.adsCount} ?????"', "' ?????'")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
