# Go to project > Repository and set the branch filter
# Then click on "View Key" and paste it on github
dart --version
pub get

echo "\n> Ensure that the code is warning free"
dartanalyzer lib/preprocessor.dart || exit 1
dartanalyzer test/test.dart || exit 1

echo "\n> Run tests"
dart --enable-type-checks --enable-asserts test/test.dart || exit 1

#echo "> Run build"
#pub build

echo "\n> Generate docs"
dartdoc lib/preprocessor.dart --package-root=packages

echo "\n> Copy docs up to github gh-pages branch"
mv docs docs-tmp
git checkout gh-pages
rm -Rf docs
mv docs-tmp docs
date > date.txt
git add -A
git commit -m"auto commit from drone.io"
git remote set-url origin git@github.com:christophehurpeau/dart-preprocessor.git
git push origin gh-pages

