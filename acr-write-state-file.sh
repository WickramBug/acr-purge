echo "test" -> test.txt

git config --global user.email "wickram95@gmail.com"
git config --global user.name "WickramBug"
git status
git add test.txt
git commit -m "Update state file"
git push origin main 
